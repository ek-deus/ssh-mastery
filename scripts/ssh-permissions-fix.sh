#!/bin/bash
# Скрипт для автоматического исправления прав доступа SSH
# Использование: ./ssh-permissions-fix.sh

set -e

echo "🔒 Fixing SSH permissions..."

SSH_DIR="$HOME/.ssh"

# Проверка существования директории
if [ ! -d "$SSH_DIR" ]; then
    echo "❌ Directory $SSH_DIR does not exist. Creating..."
    mkdir -p "$SSH_DIR"
fi

# Исправление прав
chmod 700 "$SSH_DIR"
echo "✅ $SSH_DIR -> 700"

# Исправление прав для всех файлов в .ssh
find "$SSH_DIR" -type f -name "id_*" ! -name "*.pub" -exec chmod 400 {} \;
echo "✅ Private keys -> 400"

find "$SSH_DIR" -type f -name "*.pub" -exec chmod 644 {} \;
echo "✅ Public keys -> 644"

[ -f "$SSH_DIR/config" ] && chmod 600 "$SSH_DIR/config" && echo "✅ config -> 600"
[ -f "$SSH_DIR/known_hosts" ] && chmod 644 "$SSH_DIR/known_hosts" && echo "✅ known_hosts -> 644"
[ -f "$SSH_DIR/authorized_keys" ] && chmod 600 "$SSH_DIR/authorized_keys" && echo "✅ authorized_keys -> 600"

# Создание директории для сокетов (если используется multiplexing)
SOCKETS_DIR="$SSH_DIR/sockets"
if [ ! -d "$SOCKETS_DIR" ]; then
    mkdir -p "$SOCKETS_DIR"
    chmod 700 "$SOCKETS_DIR"
    echo "✅ Created $SOCKETS_DIR -> 700"
fi

echo ""
echo "🎉 All SSH permissions fixed successfully!"
echo "💡 Tip: Run 'ssh -G your-host' to verify configuration"
