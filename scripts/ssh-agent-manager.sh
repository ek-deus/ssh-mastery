#!/bin/bash
# ============================================================================
# SSH Agent Manager - Intelligent key management (Умный менеджер агент)
# Author: ek-deus | DevOps Engineer
# ============================================================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SSH_ENV="$HOME/.ssh/agent.env"
SSH_DIR="$HOME/.ssh"
LOG_FILE="$SSH_DIR/agent.log"

# Логирование
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $*${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

# Проверка, запущен ли агент
agent_running() {
    if [ -S "$SSH_AUTH_SOCK" ] 2>/dev/null; then
        ssh-add -l &>/dev/null
        return $?
    fi
    return 1
}

# Запуск нового агента
start_agent() {
    log "Starting new ssh-agent..."
    
    # Убить старые агенты (опционально)
    pkill -u "$USER" ssh-agent 2>/dev/null || true
    
    # Запустить новый агент
    eval "$(ssh-agent -s)" > /dev/null
    
    # Сохранить переменные окружения
    {
        echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
        echo "SSH_AGENT_PID=$SSH_AGENT_PID"
        echo "export SSH_AUTH_SOCK SSH_AGENT_PID"
    } > "$SSH_ENV"
    
    chmod 600 "$SSH_ENV"
    success "ssh-agent started (PID: $SSH_AGENT_PID)"
}

# Загрузка существующего агента
load_agent_env() {
    if [ -f "$SSH_ENV" ]; then
        # shellcheck source=/dev/null
        source "$SSH_ENV" > /dev/null
        if agent_running; then
            success "Loaded existing ssh-agent (PID: $SSH_AGENT_PID)"
            return 0
        fi
    fi
    return 1
}

# Добавление ключей с учетом ~/.ssh/config
add_keys_from_config() {
    log "Scanning ~/.ssh/config for IdentityFile directives..."
    
    local keys_added=0
    local keys_skipped=0
    
    # Извлечь все IdentityFile из конфига
    while IFS= read -r key_path; do
        # Раскрыть ~ до $HOME
        key_path="${key_path/#\~/$HOME}"
        
        if [ ! -f "$key_path" ]; then
            warn "Key not found: $key_path"
            continue
        fi
        
        # Проверить, не добавлен ли уже ключ
        if ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$key_path" | awk '{print $2}')"; then
            keys_skipped=$((keys_skipped + 1))
            continue
        fi
        
        # Добавить ключ
        if ssh-add "$key_path" 2>/dev/null; then
            success "Added: $(basename "$key_path")"
            keys_added=$((keys_added + 1))
        else
            error "Failed to add: $key_path"
        fi
    done < <(grep -h "IdentityFile" "$SSH_DIR/config" "$SSH_DIR/config.d"/* 2>/dev/null | \
             awk '{print $2}' | sort -u)
    
    log "Keys added: $keys_added, skipped (already loaded): $keys_skipped"
}

# Показать статус
show_status() {
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  SSH Agent Status${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    
    if agent_running; then
        success "Agent is running (PID: $SSH_AGENT_PID)"
        echo ""
        echo -e "${BLUE}Loaded keys:${NC}"
        ssh-add -l
    else
        warn "No ssh-agent is running"
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
}

# Очистка всех ключей
clear_keys() {
    if agent_running; then
        ssh-add -D > /dev/null
        success "All keys removed from agent"
    else
        warn "No agent running"
    fi
}

# Убить агент
kill_agent() {
    if [ -n "${SSH_AGENT_PID:-}" ]; then
        kill "$SSH_AGENT_PID" 2>/dev/null || true
        rm -f "$SSH_ENV"
        success "ssh-agent killed (PID: $SSH_AGENT_PID)"
        unset SSH_AUTH_SOCK SSH_AGENT_PID
    else
        warn "No agent PID found"
    fi
}

# Основная функция
main() {
    local command="${1:-start}"
    
    case "$command" in
        start)
            if ! load_agent_env; then
                start_agent
            fi
            add_keys_from_config
            ;;
        status|list)
            show_status
            ;;
        add)
            if ! agent_running; then
                start_agent
            fi
            add_keys_from_config
            ;;
        clear)
            clear_keys
            ;;
        stop|kill)
            kill_agent
            ;;
        restart)
            kill_agent 2>/dev/null || true
            start_agent
            add_keys_from_config
            ;;
        help|--help|-h)
            echo "Usage: $0 {start|stop|restart|status|add|clear|help}"
            echo ""
            echo "Commands:"
            echo "  start   - Start agent and load keys from config (default)"
            echo "  stop    - Kill the ssh-agent"
            echo "  restart - Restart agent and reload keys"
            echo "  status  - Show agent status and loaded keys"
            echo "  add     - Add all keys from ~/.ssh/config"
            echo "  clear   - Remove all keys from agent"
            ;;
        *)
            error "Unknown command: $command"
            exit 1
            ;;
    esac
}

main "$@"
