#!/bin/bash
# ============================================================================
# SSH Metrics Collector for Prometheus (via node_exporter textfile_collector)
# Author: ek-deus | DevOps Engineer
# Stack: Ubuntu, node_exporter, Prometheus, Grafana
# ============================================================================

set -euo pipefail

# Конфигурация
OUTPUT_DIR="${SSH_METRICS_DIR:-/var/lib/node_exporter/textfile_collector}"
OUTPUT_FILE="${OUTPUT_DIR}/ssh_metrics.prom"
TEMP_FILE="${OUTPUT_FILE}.tmp.$$"
LOG_SOURCE="${SSH_LOG_SOURCE:-journal}"  # journal или file
LOG_FILE="${SSH_LOG_FILE:-/var/log/auth.log}"
LOOKBACK_MINUTES="${SSH_LOOKBACK_MINUTES:-5}"
GEOIP_ENABLED="${SSH_GEOIP_ENABLED:-false}"

# Убедиться, что директория существует
mkdir -p "$OUTPUT_DIR"

# Очистка при выходе
cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# Заголовок метрик
cat > "$TEMP_FILE" << 'EOF'
# HELP ssh_active_sessions_total Number of currently active SSH sessions
# TYPE ssh_active_sessions_total gauge
# HELP ssh_active_sessions_by_user Active SSH sessions grouped by user
# TYPE ssh_active_sessions_by_user gauge
# HELP ssh_auth_attempts_total Total SSH authentication attempts (last period)
# TYPE ssh_auth_attempts_total counter
# HELP ssh_auth_failures_total Total SSH authentication failures (last period)
# TYPE ssh_auth_failures_total counter
# HELP ssh_auth_failures_by_ip Failed SSH attempts grouped by source IP
# TYPE ssh_auth_failures_by_ip gauge
# HELP ssh_auth_success_by_key Successful authentications grouped by key type
# TYPE ssh_auth_success_by_key gauge
# HELP ssh_session_duration_seconds Average duration of SSH sessions
# TYPE ssh_session_duration_seconds gauge
# HELP ssh_root_login_attempts_total Attempts to login as root
# TYPE ssh_root_login_attempts_total counter
# HELP ssh_invalid_user_attempts_total Attempts with invalid usernames
# TYPE ssh_invalid_user_attempts_total counter
# HELP ssh_info SSH server information
# TYPE ssh_info gauge
EOF

# ============================================================================
# 1. Активные сессии (через ss/who)
# ============================================================================
active_sessions=$(ss -tn state established '( dport = :22 or sport = :22 )' 2>/dev/null | \
    tail -n +2 | wc -l)
echo "ssh_active_sessions_total $active_sessions" >> "$TEMP_FILE"

# Активные сессии по пользователям
who -u 2>/dev/null | awk '{print $1}' | sort | uniq -c | \
    awk '{printf "ssh_active_sessions_by_user{user=\"%s\"} %d\n", $2, $1}' >> "$TEMP_FILE"

# ============================================================================
# 2. Получение логов SSH (универсально для systemd и файлов)
# ============================================================================
get_ssh_logs() {
    local since_time
    since_time=$(date -d "$LOOKBACK_MINUTES minutes ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                 date -v-${LOOKBACK_MINUTES}M '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
    
    if [ "$LOG_SOURCE" = "journal" ]; then
        journalctl -u ssh -u sshd --since "$since_time" --no-pager -q 2>/dev/null || true
    else
        # Для файловых логов используем awk для фильтрации по времени
        if [ -f "$LOG_FILE" ]; then
            awk -v since="$since_time" '$0 >= since' "$LOG_FILE" 2>/dev/null | \
                grep -i sshd || true
        fi
    fi
}

# Получить логи один раз и сохранить
SSH_LOGS=$(get_ssh_logs)

# ============================================================================
# 3. Успешные аутентификации
# ============================================================================
auth_success=$(echo "$SSH_LOGS" | grep -c "Accepted" || echo 0)
echo "ssh_auth_attempts_total{status=\"success\"} $auth_success" >> "$TEMP_FILE"

# По типу ключа
echo "$SSH_LOGS" | grep "Accepted" | \
    grep -oE "Accepted (publickey|password|keyboard-interactive)" | \
    awk '{print $2}' | sort | uniq -c | \
    awk '{printf "ssh_auth_success_by_key{method=\"%s\"} %d\n", $2, $1}' >> "$TEMP_FILE"

# ============================================================================
# 4. Неуспешные аутентификации
# ============================================================================
auth_failures=$(echo "$SSH_LOGS" | grep -cE "(Failed password|Invalid user|authentication failure)" || echo 0)
echo "ssh_auth_attempts_total{status=\"failure\"} $auth_failures" >> "$TEMP_FILE"
echo "ssh_auth_failures_total $auth_failures" >> "$TEMP_FILE"

# Неуспешные попытки по IP
echo "$SSH_LOGS" | grep -E "(Failed password|Invalid user)" | \
    grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort | uniq -c | sort -rn | head -20 | \
    awk '{printf "ssh_auth_failures_by_ip{ip=\"%s\"} %d\n", $2, $1}' >> "$TEMP_FILE"

# ============================================================================
# 5. Попытки входа под root
# ============================================================================
root_attempts=$(echo "$SSH_LOGS" | grep -cE "(Failed password for root|Invalid user root)" || echo 0)
echo "ssh_root_login_attempts_total $root_attempts" >> "$TEMP_FILE"

# ============================================================================
# 6. Invalid users
# ============================================================================
invalid_users=$(echo "$SSH_LOGS" | grep -c "Invalid user" || echo 0)
echo "ssh_invalid_user_attempts_total $invalid_users" >> "$TEMP_FILE"

# Топ invalid usernames
echo "$SSH_LOGS" | grep "Invalid user" | \
    awk '{for(i=1;i<=NF;i++) if($i=="user") print $(i+1)}' | \
    sort | uniq -c | sort -rn | head -10 | \
    awk '{printf "ssh_invalid_usernames_top{username=\"%s\"} %d\n", $2, $1}' >> "$TEMP_FILE"

# ============================================================================
# 7. Средняя длительность сессий (через last)
# ============================================================================
avg_duration=$(last -F 2>/dev/null | grep -v "reboot" | head -50 | \
    awk '/still logged in/ {next} 
         {
            split($0, a, " "); 
            for(i=1;i<=NF;i++) {
                if($i ~ /\([0-9]+:[0-9]+\)/) {
                    split($i, t, /[:()]/);
                    if(length(t)>=3) print t[2]*3600 + t[3]*60
                }
            }
         }' | awk '{sum+=$1; n++} END {if(n>0) print sum/n; else print 0}')
echo "ssh_session_duration_seconds ${avg_duration:-0}" >> "$TEMP_FILE"

# ============================================================================
# 8. Информация о сервере
# ============================================================================
sshd_version=$(sshd -V 2>&1 | head -1 || ssh -V 2>&1 | head -1)
echo "ssh_info{version=\"$sshd_version\",hostname=\"$(hostname)\"} 1" >> "$TEMP_FILE"

# ============================================================================
# 9. GeoIP информация (опционально, требует geoiplookup)
# ============================================================================
if [ "$GEOIP_ENABLED" = "true" ] && command -v geoiplookup &>/dev/null; then
    echo "$SSH_LOGS" | grep "Failed password" | \
        grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort -u | head -20 | \
        while read -r ip; do
            country=$(geoiplookup "$ip" 2>/dev/null | awk -F: '{print $2}' | awk '{print $1}' || echo "Unknown")
            count=$(echo "$SSH_LOGS" | grep -c "$ip" || echo 0)
            echo "ssh_failures_by_country{country=\"$country\",ip=\"$ip\"} $count"
        done >> "$TEMP_FILE"
fi

# ============================================================================
# 10. Атомарная замена файла (безопасно для node_exporter)
# ============================================================================
chmod 644 "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "✅ SSH metrics collected at $(date -Iseconds)" >&2
