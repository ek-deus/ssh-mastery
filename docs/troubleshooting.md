# 🔧 SSH Troubleshooting Guide

## Проблема: `Permissions denied (publickey)`

### Причины:
1. Неправильные права доступа к ключам или `.ssh/`
2. Ключ не добавлен в `~/.ssh/config`
3. Публичный ключ не добавлен на сервер в `~/.ssh/authorized_keys`
4. SSH-агент не запущен или ключ не добавлен в него

### Решение:
```bash
# 1. Исправить права доступа
./scripts/ssh-permissions-fix.sh

# 2. Проверить, какой ключ используется
ssh -v your-host 2>&1 | grep identity

# 3. Добавить ключ в агент
ssh-add ~/.ssh/id_ed25519_your_key

# 4. Проверить конфиг
ssh -G your-host | grep identityfile
