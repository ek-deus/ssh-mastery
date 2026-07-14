#!/bin/bash
# Генератор SSH-ключей с правильными параметрами безопасности
# Использование: ./ssh-key-generator.sh <key-name> [email]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <key-name> [email]"
    echo "Example: $0 id_ed25519_vps user@example.com"
    exit 1
fi

KEY_NAME="$1"
EMAIL="${2:-}"
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"

# Проверка существования
if [ -f "$KEY_PATH" ]; then
    echo "❌ Key $KEY_PATH already exists!"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Создание директории
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Генерация ключа
echo "🔑 Generating Ed25519 key: $KEY_NAME"

if [ -n "$EMAIL" ]; then
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N ""
fi

# Установка правильных прав
chmod 400 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

echo ""
echo "✅ Key generated successfully!"
echo "📍 Private key: $KEY_PATH"
echo "📍 Public key: $KEY_PATH.pub"
echo ""
echo "📋 Public key content:"
cat "$KEY_PATH.pub"
echo ""
echo "💡 Add this to your ~/.ssh/config:"
echo "Host your-host"
echo "    IdentityFile $KEY_PATH"
echo "    IdentitiesOnly yes"
