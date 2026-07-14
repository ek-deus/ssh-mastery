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
```

## Проблема: Connection timed out
Причины:
Неправильный IP/домен
Firewall блокирует порт
SSH-сервер не запущен на удаленной машине
### Решение:
```bash
# 1. Проверить доступность порта
nc -zv your-host 22

# 2. Проверить с verbose mode
ssh -v your-host

# 3. Если используется нестандартный порт, проверить конфиг
ssh -G your-host | grep port
```
## Проблема: Too many authentication failures
Причина:
SSH перебирает слишком много ключей из агента и сервер отклоняет подключение.
### Решение:
Добавьте в ~/.ssh/config для конкретного хоста:
```ini
Host your-host
    IdentitiesOnly yes
    IdentityFile ~/.ssh/specific_key
```

## Проблема: Multiplexing не работает
Причины:
Директория для сокетов не существует
Неправильные права на директорию сокетов
### Решение:
```bash
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets

# Проверить статус соединения
ssh -O check your-host

---

## 🎯 Что делать прямо сейчас:

1. **Создай структуру папок**:
   ```bash
   mkdir -p config.d scripts snippets ansible/roles/ssh-config/{tasks,templates,defaults} docs

```

Добавь файлы из примеров выше
Сделай скрипты исполняемыми:
```bash
   chmod +x scripts/*.sh
```
Закоммить и запушь:
```bash
   git add .
   git commit -m "feat: add SSH config examples, scripts, and documentation"
   git push origin main
```


