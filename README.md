<div align="center">

  <img src="https://media.giphy.com/media/26tn33aiTi1jkl6H6/giphy.gif" alt="Terminal Hacking" width="100%" style="border-radius: 8px; opacity: 0.8;" />
  
  <h1>🔐 SSH Mastery & Config Management</h1>
  <h3>Искусство управления множественными ключами, туннелями и инфраструктурой доступа</h3>

  <p>
    <img src="https://img.shields.io/badge/OS-Linux-000000?style=flat-square&logo=linux&logoColor=white" alt="Linux" />
    <img src="https://img.shields.io/badge/Tool-OpenSSH-000000?style=flat-square&logo=openssh&logoColor=white" alt="OpenSSH" />
    <img src="https://img.shields.io/badge/Style-Dark_Hacker_Mode-00ff00?style=flat-square" alt="Style" />
    <img src="https://img.shields.io/badge/DevOps-Infrastructure_as_Code-9900ff?style=flat-square" alt="DevOps" />
  </p>

  <p><i>"Я не пишу <code>ssh -i ~/.ssh/key user@host</code>. Я пишу <code>ssh prod</code>, и всё работает."</i></p>
</div>

---

## 📖 Оглавление
- [🗺️ Архитектура и потоки данных](#️-архитектура-и-потоки-данных)
- [📂 Структура репозитория](#-структура-репозитория)
- [🧠 Философия](#-философия)
- [🏗️ Анатомия идеального блока](#️-анатомия-идеального-блока)
- [🚀 Реальные сценарии (VPS, HomeLab, GitHub)](#-реальные-сценарии)
- [⚡ DevOps Superpowers (ProxyJump, Multiplexing)](#-devops-superpowers)
- [📊 Мониторинг и алертинг (Prometheus + Grafana)](#-мониторинг-и-алертинг)
- [🤖 Автоматизация (Ansible + GitHub Actions)](#-автоматизация)
- [🔒 Железобетонная безопасность](#-железобетонная-безопасность)
- [🛠️ Отладка и диагностика](#️-отладка-и-диагностика)
- [📦 Быстрый старт (Deploy)](#-быстрый-старт-deploy)

---

## 🗺️ Архитектура и потоки данных

Визуализация того, как этот репозиторий организует доступ к сложной инфраструктуре:

```mermaid
graph TD
    A[👤 DevOps Engineer] -->|ssh vps-bot| B(🌐 Ubuntu VPS)
    A -->|ssh rke2-node-1| C{🛡️ Bastion Host}
    C -->|ProxyJump| D[🐳 RKE2 Node 1]
    C -->|ProxyJump| E[🐳 RKE2 Node 2]
    
    B -.->|textfile_collector| F[📊 Prometheus]
    D -.->|textfile_collector| F
    F --> G[📈 Grafana Dashboard]
    F -->|Alerts| H[🔔 Telegram/Slack]
    
    I[🤖 GitHub Actions] -->|Ansible Playbook| B
    I -->|Ansible Playbook| C
    
    style A fill:#1a1a1a,stroke:#00ff00,stroke-width:2px,color:#fff
    style C fill:#2d1b4e,stroke:#9900ff,stroke-width:2px,color:#fff
    style F fill:#1a1a1a,stroke:#E6522C,stroke-width:2px,color:#fff
```
---
```text
ssh-mastery/
├── .github/workflows/       # CI/CD: валидация конфигов и авто-деплой через Ansible
├── ansible/                 # Ansible роль для массового развертывания SSH-конфигов
├── config.d/                # Модульные примеры конфигов (VPS, HomeLab, GitHub, Bastion)
├── docs/                    # Расширенная документация и troubleshooting
├── grafana/                 # Готовый JSON-дашборд для мониторинга SSH-безопасности
├── prometheus/              # Alerting rules (brute-force, root login, аномалии)
├── scripts/                 # Утилиты: генерация ключей, фикс прав, сбор метрик (Bash/Python)
├── snippets/                # Готовые алиасы и функции для ~/.bashrc или ~/.zshrc
├── systemd/                 # Timer и Service для автоматического сбора метрик
└── README.md                # Ты находишься здесь
```
---

## 🧠 Философия

Если вы управляете личным **Ubuntu VPS** для деплоя приложений, домашним сервером (**RKE2/Kubernetes**), рабочими кластерами и несколькими аккаунтами GitHub, ручное указание ключей (`-i`) — это путь к хаосу и ошибкам. 

Файл `~/.ssh/config` (или директория `~/.ssh/config.d/`) — это ваш центральный, декларативный пульт управления доступом. Он должен быть таким же чистым и версионируемым, как и ваш Ansible-код.

---

## 🏗️ Анатомия идеального блока

Каждый блок начинается с директивы `Host` (это **алиас**, который вы вводите в терминале), за которым следуют параметры подключения.

```ini
# ~/.ssh/config.d/vps
Host vps-bot
    HostName vps.ekdeus.me            # Реальный IP или домен
    User deploy                       # Пользователь по умолчанию
    IdentityFile ~/.ssh/id_ed25519_vps # Путь к конкретному приватному ключу
    IdentitiesOnly yes                # КРИТИЧНО: запрещает SSH перебирать все ключи из агента
    Port 2222                         # Нестандартный порт (если применимо)
    ServerAliveInterval 60            # Защита от разрыва соединения (keep-alive)
    ServerAliveCountMax 3
    AddKeysToAgent yes                # Автоматически добавлять ключ в ssh-agent при первом успехе
```
## Разделение личного и рабочего GitHub

Чтобы коммиты и пуши уходили с правильным аккаунтом без плясок с GIT_SSH_COMMAND.

```ini
# Личный GitHub (ek-deus)
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes

# Рабочий GitHub (UseTech)
Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes
```

💡 Применение: git remote set-url origin [git@github.com:ek-deus/ssh-mastery.git](https://github.com/ek-deus/ssh-mastery.git)
## 🏠 Домашний сервер (Home Lab)
Мой локальный парк: AMD Ryzen 7 Pro 5750G, 64GB RAM, RX6600, управляемый через Ansible.

```ini
Host homelab-*
    User admin
    IdentityFile ~/.ssh/id_ed25519_homelab
    IdentitiesOnly yes
    # Включаем проброс агента для цепочки подключений внутри сети
    ForwardAgent yes 
```

## ⚡ DevOps Superpowers
🔗 ProxyJump (Доступ к закрытым нодам RKE2)
Забудьте о копировании приватных ключей на бастион-хост. SSH построит безопасный туннель автоматически.
```ini
# Публичный бастион (VPS)
Host bastion
    HostName bastion.ekdeus.me
    User admin
    IdentityFile ~/.ssh/id_ed25519_bastion
    IdentitiesOnly yes

# Внутренние ноды Kubernetes (доступны ТОЛЬКО через бастион)
Host rke2-node-*
    User root
    IdentityFile ~/.ssh/id_ed25519_internal
    IdentitiesOnly yes
    ProxyJump bastion  # Магия: ssh rke2-node-1 автоматически пройдет через bastion
```

## 🏎️ Ускорение Ansible в 10 раз (Connection Multiplexing)
Ansible открывает новое SSH-соединение для каждой задачи. Multiplexing переиспользует один TCP-канал, радикально снижая latency.
```ini
# ~/.ssh/config (Глобальные настройки)
Host *
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m  # Держать соединение открытым 10 минут после последнего использования
```

## ⚠️ Важно: Создайте директорию заранее:
mkdir -p ~/.ssh/sockets && chmod 700 ~/.ssh/sockets
📁 Модульность (Include)
Не сваливайте всё в одну простыню. Разделяйте контексты как в Ansible.
```ini
# В самом начале ~/.ssh/config
Include ~/.ssh/config.d/*
```
---
## 📊 Мониторинг и алертинг
Репозиторий включает полноценный стек для отслеживания SSH-активности:
scripts/ssh-metrics-collector.py: Сбор метрик (успешные/неуспешные входы, топ атакующих IP, brute-force детекция).
prometheus/ssh_rules.yml: Готовые алерты (например, SSHBruteForceDetected или SSHRootLoginAttempts).
grafana/ssh-monitoring-dashboard.json: Стильный темный дашборд для визуализации угроз и активных сессий.

## 🤖 Автоматизация
Ansible: Роль ansible/roles/ssh-config для идемпотентного развертывания конфигов и прав доступа на всех управляемых нодах.
GitHub Actions:
ssh-config-validation.yml: Проверка синтаксиса и прав доступа при каждом PR.
ansible-ssh-deploy.yml: Автоматический деплой обновленных конфигов на серверы при мерже в main.

---
## 🔒 Железобетонная безопасность
OpenSSH крайне чувствителен к правам доступа. Неправильные права = Permissions denied или молчаливое игнорирование конфига.
Выполните этот чеклист один раз:
```bash
chmod 700 ~/.ssh
chmod 400 ~/.ssh/id_*          # СТРОГО чтение для владельца
chmod 644 ~/.ssh/*.pub         # Публичные ключи
chmod 600 ~/.ssh/config        # Файл конфигурации
chmod 600 ~/.ssh/config.d/*    # Файлы в директории config.d
chmod 700 ~/.ssh/sockets       # Директория для мультиплексирования
```

## 🛠️ Отладка и диагностика
Прежде чем гадать, почему не работает, спросите у SSH, как он интерпретирует ваш конфиг.
Показать разрешенные параметры для конкретного хоста (идеально для проверки):

```bash
   ssh -G vps-bot | grep -i identityfile
```

Режим подробной отладки (показывает, какой ключ реально предлагается серверу и где происходит сбой):
```bash
   ssh -v vps-bot
```
Проверка синтаксиса всех конфигов (без реального подключения):
```bash
   ssh -F ~/.ssh/config -G dummy-host > /dev/null && echo "✅ Config syntax is valid"
```
---


📦 Быстрый старт (Deploy)
Чтобы развернуть эту конфигурацию на новой машине:
```bash
# 1. Клонируем репозиторий во временную директорию
git clone https://github.com/ek-deus/ssh-mastery.git ~/.ssh.tmp

# 2. Создаем необходимые директории
mkdir -p ~/.ssh/config.d ~/.ssh/sockets

# 3. Копируем примеры конфигураций хостов
cp ~/.ssh.tmp/config.d/* ~/.ssh/config.d/

# 4. Добавляем директиву Include в ваш существующий ~/.ssh/config (если её там нет)
echo -e "\n# Modular SSH configs\nInclude ~/.ssh/config.d/*" >> ~/.ssh/config

# 5. Удаляем временные файлы
rm -rf ~/.ssh.tmp

# 6. КРИТИЧЕСКИ ВАЖНО: Применяем правильные права доступа
chmod 700 ~/.ssh ~/.ssh/config.d ~/.ssh/sockets
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/config.d/*
chmod 400 ~/.ssh/id_* 2>/dev/null || true
```

<div align="center">
<sub>Built with 💻, ☕ and strict permissions by <b>ek-deus</b></sub>
<br>
<img src="https://img.shields.io/badge/DevOps-Kubernetes%20%7C%20Ansible%20%7C%20Prometheus-000000?style=for-the-badge&logo=dev.to&logoColor=white" alt="DevOps Stack" />
</div>


---

### 🎯 Что делать дальше:
1. Создай репозиторий `ssh-mastery` (или `dotfiles`) на GitHub.
2. Скопируй этот текст в `README.md`.
3. Создай папку `config.d/` и добавь туда пример файла (например, `example-vps`), чтобы показать структуру.
4. **Закрепи (Pin)** этот репозиторий в профиле GitHub.
5. В главном профиле (`ek-deus/ek-deus`) добавь строку:  
   `🔐 Автор гайда по [мастерству управления SSH и мультиплексированию](https://github.com/ek-deus/ssh-mastery)`

