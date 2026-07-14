# SSH Aliases and Functions for Bash
# Добавьте это в ~/.bashrc

# Быстрое подключение к часто используемым хостам
alias cvps='ssh vps-production'
alias chome='ssh home-server'
alias cwork='ssh github.com-work'

# Функция для копирования файлов с учетом SSH config
scpf() {
    if [ $# -ne 2 ]; then
        echo "Usage: scpf <source> <destination>"
        echo "Example: scpf ./local-file.txt vps-production:/tmp/"
        return 1
    fi
    scp -F ~/.ssh/config "$1" "$2"
}

# Функция для синхронизации директорий
rsyncf() {
    if [ $# -ne 2 ]; then
        echo "Usage: rsyncf <source> <destination>"
        echo "Example: rsyncf ./local-dir/ vps-production:/var/www/"
        return 1
    fi
    rsync -avz -e "ssh -F ~/.ssh/config" "$1" "$2"
}

# Функция для проверки доступности хоста через SSH
ssh-check() {
    if [ -z "$1" ]; then
        echo "Usage: ssh-check <host>"
        return 1
    fi
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$1" exit 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ $1 is reachable"
    else
        echo "❌ $1 is not reachable"
    fi
}

# Функция для показа всех настроенных хостов
ssh-hosts() {
    echo "📋 Configured SSH hosts:"
    grep -E "^Host " ~/.ssh/config ~/.ssh/config.d/* 2>/dev/null | \
        awk '{print "  - " $2}' | sort | uniq
}
