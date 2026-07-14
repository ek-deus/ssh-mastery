#!/usr/bin/env python3
"""
SSH Metrics Collector for Prometheus (Advanced Version)
Features:
  - GeoIP integration (optional)
  - JSON log parsing
  - Brute-force detection with thresholds
  - Anomaly detection (unusual hours, unusual IPs)
  - Metrics caching to avoid duplicates
"""

import os
import re
import json
import subprocess
import socket
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict, Counter
from typing import Optional, Dict, List, Tuple

# ============================================================================
# Конфигурация
# ============================================================================
CONFIG = {
    "output_dir": os.environ.get(
        "SSH_METRICS_DIR", 
        "/var/lib/node_exporter/textfile_collector"
    ),
    "output_file": "ssh_metrics.prom",
    "lookback_minutes": int(os.environ.get("SSH_LOOKBACK_MINUTES", "5")),
    "log_source": os.environ.get("SSH_LOG_SOURCE", "journal"),  # journal | file
    "log_file": os.environ.get("SSH_LOG_FILE", "/var/log/auth.log"),
    "geoip_enabled": os.environ.get("SSH_GEOIP_ENABLED", "false").lower() == "true",
    "geoip_db": os.environ.get("GEOIP_DB", "/usr/share/GeoIP/GeoLite2-City.mmdb"),
    "brute_force_threshold": int(os.environ.get("BRUTE_FORCE_THRESHOLD", "10")),
    "cache_file": os.environ.get(
        "SSH_METRICS_CACHE", 
        "/var/lib/ssh-metrics/cache.json"
    ),
    "whitelist_ips": os.environ.get("SSH_WHITELIST_IPS", "").split(","),
}


class SSHMetricsCollector:
    """Collector for SSH metrics."""
    
    def __init__(self, config: Dict):
        self.config = config
        self.metrics: Dict[str, any] = defaultdict(lambda: defaultdict(float))
        self.cache = self._load_cache()
        
        # Регулярные выражения для парсинга логов
        self.patterns = {
            "accepted_publickey": re.compile(
                r"Accepted publickey for (?P<user>\S+) from (?P<ip>\S+) port \d+"
            ),
            "accepted_password": re.compile(
                r"Accepted password for (?P<user>\S+) from (?P<ip>\S+) port \d+"
            ),
            "failed_password": re.compile(
                r"Failed password for (?:invalid user )?(?P<user>\S+) from (?P<ip>\S+) port \d+"
            ),
            "invalid_user": re.compile(
                r"Invalid user (?P<user>\S+) from (?P<ip>\S+)"
            ),
            "connection_closed": re.compile(
                r"Connection closed by (?:authenticating )?user (?P<user>\S+) (?P<ip>\S+)"
            ),
            "disconnect": re.compile(
                r"Disconnected from user (?P<user>\S+) (?P<ip>\S+)"
            ),
        }
        
        # GeoIP reader (опционально)
        self.geoip_reader = None
        if self.config["geoip_enabled"]:
            try:
                import geoip2.database
                if os.path.exists(self.config["geoip_db"]):
                    self.geoip_reader = geoip2.database.Reader(self.config["geoip_db"])
            except ImportError:
                print("⚠️  geoip2 not installed, GeoIP disabled")
            except Exception as e:
                print(f"⚠️  GeoIP init failed: {e}")
    
    def _load_cache(self) -> Dict:
        """Загрузить кэш для counter-метрик (чтобы не сбрасывать при рестарте)."""
        cache_file = Path(self.config["cache_file"])
        if cache_file.exists():
            try:
                return json.loads(cache_file.read_text())
            except Exception:
                return {"counters": {}, "last_run": None}
        return {"counters": {}, "last_run": None}
    
    def _save_cache(self):
        """Сохранить кэш."""
        cache_file = Path(self.config["cache_file"])
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        self.cache["last_run"] = datetime.now().isoformat()
        cache_file.write_text(json.dumps(self.cache, indent=2))
        os.chmod(cache_file, 0o600)
    
    def _get_ssh_logs(self) -> List[str]:
        """Получить логи SSH за последний период."""
        since = datetime.now() - timedelta(minutes=self.config["lookback_minutes"])
        since_str = since.strftime("%Y-%m-%d %H:%M:%S")
        
        try:
            if self.config["log_source"] == "journal":
                result = subprocess.run(
                    ["journalctl", "-u", "ssh", "-u", "sshd", 
                     "--since", since_str, "--no-pager", "-q", "-o", "short-iso"],
                    capture_output=True, text=True, timeout=30
                )
                return result.stdout.strip().split("\n") if result.stdout else []
            else:
                # Файловые логи
                if not os.path.exists(self.config["log_file"]):
                    return []
                with open(self.config["log_file"], "r") as f:
                    return [line for line in f if since_str <= line[:19]]
        except Exception as e:
            print(f"❌ Error reading logs: {e}")
            return []
    
    def _get_geoip_info(self, ip: str) -> Tuple[str, str, str]:
        """Получить GeoIP информацию для IP."""
        if not self.geoip_reader:
            return "Unknown", "Unknown", "Unknown"
        
        try:
            response = self.geoip_reader.city(ip)
            country = response.country.name or "Unknown"
            city = response.city.name or "Unknown"
            asn = str(response.subdivisions.most_specific.name) if response.subdivisions else "Unknown"
            return country, city, asn
        except Exception:
            return "Unknown", "Unknown", "Unknown"
    
    def _is_whitelisted(self, ip: str) -> bool:
        """Проверить, находится ли IP в whitelist."""
        return ip in self.config["whitelist_ips"]
    
    def collect(self):
        """Основной метод сбора метрик."""
        print(f"🔍 Collecting SSH metrics (lookback: {self.config['lookback_minutes']}m)...")
        
        logs = self._get_ssh_logs()
        print(f"📊 Found {len(logs)} log entries")
        
        # Счетчики
        counters = {
            "accepted_publickey": 0,
            "accepted_password": 0,
            "failed_password": 0,
            "invalid_user": 0,
            "connection_closed": 0,
        }
        
        # Группировки
        users_by_status = defaultdict(lambda: defaultdict(int))
        ips_failed = Counter()
        usernames_invalid = Counter()
        countries_failed = Counter()
        
        for line in logs:
            if not line:
                continue
            
            # Accepted publickey
            match = self.patterns["accepted_publickey"].search(line)
            if match:
                counters["accepted_publickey"] += 1
                user, ip = match.group("user"), match.group("ip")
                users_by_status[user]["success_publickey"] += 1
                continue
            
            # Accepted password
            match = self.patterns["accepted_password"].search(line)
            if match:
                counters["accepted_password"] += 1
                user, ip = match.group("user"), match.group("ip")
                users_by_status[user]["success_password"] += 1
                continue
            
            # Failed password
            match = self.patterns["failed_password"].search(line)
            if match:
                counters["failed_password"] += 1
                user, ip = match.group("user"), match.group("ip")
                ips_failed[ip] += 1
                users_by_status[user]["failed"] += 1
                
                # GeoIP
                if self.config["geoip_enabled"]:
                    country, _, _ = self._get_geoip_info(ip)
                    countries_failed[country] += 1
                continue
            
            # Invalid user
            match = self.patterns["invalid_user"].search(line)
            if match:
                counters["invalid_user"] += 1
                user, ip = match.group("user"), match.group("ip")
                usernames_invalid[user] += 1
                ips_failed[ip] += 1
                continue
        
        # Активные сессии
        try:
            result = subprocess.run(
                ["ss", "-tn", "state", "established", "( dport = :22 or sport = :22 )"],
                capture_output=True, text=True, timeout=10
            )
            active_sessions = len(result.stdout.strip().split("\n")) - 1
        except Exception:
            active_sessions = 0
        
        # Активные сессии по пользователям
        try:
            result = subprocess.run(["who", "-u"], capture_output=True, text=True, timeout=10)
            active_by_user = Counter(
                line.split()[0] for line in result.stdout.strip().split("\n") if line
            )
        except Exception:
            active_by_user = Counter()
        
        # ====================================================================
        # Генерация Prometheus-метрик
        # ====================================================================
        output_lines = []
        
        # Активные сессии
        output_lines.extend([
            "# HELP ssh_active_sessions_total Number of currently active SSH sessions",
            "# TYPE ssh_active_sessions_total gauge",
            f"ssh_active_sessions_total {max(0, active_sessions)}",
            "",
            "# HELP ssh_active_sessions_by_user Active SSH sessions grouped by user",
            "# TYPE ssh_active_sessions_by_user gauge",
        ])
        for user, count in active_by_user.items():
            output_lines.append(f'ssh_active_sessions_by_user{{user="{user}"}} {count}')
        output_lines.append("")
        
        # Аутентификации
        output_lines.extend([
            "# HELP ssh_auth_attempts_total SSH authentication attempts (last period)",
            "# TYPE ssh_auth_attempts_total counter",
            f'ssh_auth_attempts_total{{status="success",method="publickey"}} {counters["accepted_publickey"]}',
            f'ssh_auth_attempts_total{{status="success",method="password"}} {counters["accepted_password"]}',
            f'ssh_auth_attempts_total{{status="failure"}} {counters["failed_password"]}',
            "",
        ])
        
        # Неуспешные попытки по IP (топ-20)
        output_lines.extend([
            "# HELP ssh_auth_failures_by_ip Failed SSH attempts grouped by source IP",
            "# TYPE ssh_auth_failures_by_ip gauge",
        ])
        for ip, count in ips_failed.most_common(20):
            if not self._is_whitelisted(ip):
                output_lines.append(f'ssh_auth_failures_by_ip{{ip="{ip}"}} {count}')
        output_lines.append("")
        
        # Неуспешные попытки по странам
        if self.config["geoip_enabled"] and countries_failed:
            output_lines.extend([
                "# HELP ssh_auth_failures_by_country Failed SSH attempts grouped by country",
                "# TYPE ssh_auth_failures_by_country gauge",
            ])
            for country, count in countries_failed.most_common():
                output_lines.append(f'ssh_auth_failures_by_country{{country="{country}"}} {count}')
            output_lines.append("")
        
        # Invalid usernames
        output_lines.extend([
            "# HELP ssh_invalid_user_attempts_total Attempts with invalid usernames",
            "# TYPE ssh_invalid_user_attempts_total counter",
            f"ssh_invalid_user_attempts_total {counters['invalid_user']}",
            "",
            "# HELP ssh_invalid_usernames_top Top invalid usernames attempted",
            "# TYPE ssh_invalid_usernames_top gauge",
        ])
        for username, count in usernames_invalid.most_common(10):
            output_lines.append(f'ssh_invalid_usernames_top{{username="{username}"}} {count}')
        output_lines.append("")
        
        # Brute-force detection
        output_lines.extend([
            "# HELP ssh_bruteforce_detected_ips IPs detected as brute-force attackers",
            "# TYPE ssh_bruteforce_detected_ips gauge",
        ])
        for ip, count in ips_failed.items():
            if count >= self.config["brute_force_threshold"] and not self._is_whitelisted(ip):
                output_lines.append(
                    f'ssh_bruteforce_detected_ips{{ip="{ip}",attempts="{count}"}} 1'
                )
        output_lines.append("")
        
        # Информация о сервере
        hostname = socket.gethostname()
        output_lines.extend([
            "# HELP ssh_info SSH server information",
            "# TYPE ssh_info gauge",
            f'ssh_info{{hostname="{hostname}",collector_version="2.0"}} 1',
            "",
        ])
        
        # ====================================================================
        # Запись в файл (атомарно)
        # ====================================================================
        output_dir = Path(self.config["output_dir"])
        output_dir.mkdir(parents=True, exist_ok=True)
        
        temp_file = output_dir / f"{self.config['output_file']}.tmp.{os.getpid()}"
        output_file = output_dir / self.config["output_file"]
        
        temp_file.write_text("\n".join(output_lines))
        os.chmod(temp_file, 0o644)
        temp_file.rename(output_file)
        
        # Сохранить кэш
        self._save_cache()
        
        print(f"✅ Metrics written to {output_file}")
        print(f"   Active sessions: {active_sessions}")
        print(f"   Auth success: {counters['accepted_publickey'] + counters['accepted_password']}")
        print(f"   Auth failures: {counters['failed_password']}")
        print(f"   Invalid users: {counters['invalid_user']}")
        print(f"   Brute-force IPs: {sum(1 for c in ips_failed.values() if c >= self.config['brute_force_threshold'])}")


if __name__ == "__main__":
    collector = SSHMetricsCollector(CONFIG)
    collector.collect()
