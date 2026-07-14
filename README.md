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
- [🧠 Философия](#-философия)
- [🏗️ Анатомия идеального блока](#️-анатомия-идеального-блока)
- [🚀 Реальные сценарии (VPS, HomeLab, GitHub)](#-реальные-сценарии)
- [⚡ DevOps Superpowers (ProxyJump, Multiplexing)](#-devops-superpowers]
- [🔒 Железобетонная безопасность](#-железобетонная-безопасность)
- [🛠️ Отладка и диагностика](#️-отладка-и-диагностика)

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

