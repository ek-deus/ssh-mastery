# ============================================================================
# SSH Agent Auto-Start for Bash Интерграция Bash
# Добавьте это в ~/.bashrc
# ============================================================================

# Путь к менеджеру агента
SSH_AGENT_MANAGER="$HOME/.local/bin/ssh-agent-manager.sh"

# Автоматический запуск агента при открытии терминала
_ssh_agent_init() {
    local ssh_env="$HOME/.ssh/agent.env"
    
    # Загрузить существующий агент
    if [ -f "$ssh_env" ]; then
        # shellcheck source=/dev/null
        source "$ssh_env" > /dev/null
        
        # Проверить, жив ли агент
        if ! ssh-add -l &>/dev/null; then
            # Агент мертв, запустить новый
            if [ -x "$SSH_AGENT_MANAGER" ]; then
                eval "$("$SSH_AGENT_MANAGER" start 2>/dev/null)"
            else
                eval "$(ssh-agent -s)" > /dev/null
                {
                    echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
                    echo "SSH_AGENT_PID=$SSH_AGENT_PID"
                    echo "export SSH_AUTH_SOCK SSH_AGENT_PID"
                } > "$ssh_env"
                chmod 600 "$ssh_env"
            fi
        fi
    else
        # Нет env-файла, запустить агент
        if [ -x "$SSH_AGENT_MANAGER" ]; then
            eval "$("$SSH_AGENT_MANAGER" start 2>/dev/null)"
        else
            eval "$(ssh-agent -s)" > /dev/null
            {
                echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
                echo "SSH_AGENT_PID=$SSH_AGENT_PID"
                echo "export SSH_AUTH_SOCK SSH_AGENT_PID"
            } > "$ssh_env"
            chmod 600 "$ssh_env"
        fi
    fi
}

# Запустить только в интерактивных сессиях
if [[ $- == *i* ]] && [ -z "$SSH_AUTH_SOCK" ]; then
    _ssh_agent_init
fi

# Алиасы для быстрого управления
alias ssh-status='ssh-add -l 2>/dev/null || echo "No agent running"'
alias ssh-clear='ssh-add -D 2>/dev/null && echo "All keys cleared"'
alias ssh-restart='pkill -u "$USER" ssh-agent 2>/dev/null; eval "$(ssh-agent -s)" > /dev/null'

# Функция для добавления ключа с таймаутом
ssh-add-timed() {
    local timeout="${1:-1h}"
    local key="${2:-}"
    
    if [ -z "$key" ]; then
        ssh-add -t "$timeout"
    else
        ssh-add -t "$timeout" "$key"
    fi
}

# Автодополнение для ssh-add-timed
_ssh_add_timed_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=($(compgen -W "30m 1h 4h 8h 1d" -- "$cur"))
    elif [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=($(compgen -f -- "$cur"))
    fi
}
complete -F _ssh_add_timed_complete ssh-add-timed
