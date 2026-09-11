# Navigation
alias ..='cd ..'
alias ...='cd ../..'

# ls -> eza si dispo
if command -q eza
    alias ls='eza --icons'
    alias ll='eza -lah --icons --git --group-directories-first'
    alias la='eza -la --icons --git'
    alias lt='eza --tree --icons --level=2'
    alias lth='eza -a --tree --icons --level=2'
else
    alias ls='ls --color=auto'
    alias ll='ls -lah'
    alias la='ls -lhAF'
end

# cat -> bat si dispo
if command -q bat
    alias cat='bat --paging=never'
end

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gcam='git commit -am'
alias gp='git push'
alias gpl='git pull'
alias gfp='git fetch --prune'
alias gl='git log --oneline --graph --decorate'
alias gr='git restore'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcod='git checkout dev'
alias gcom='git checkout main'
alias gb='git branch'
alias gbr='git branch -r'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gbm='git branch -m'
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gd='git diff'
alias gds='git diff --staged'
alias grs='git restore --staged'
alias grb='git rebase'
alias gm='git merge'
alias gsw='git switch'
alias gswc='git switch -c'

# Docker
alias d='docker'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dps='docker ps'
alias dlogs='docker logs -f'

# Systeme
alias myip='curl -s https://api.ipify.org && echo'
alias ports='ss -tulnp'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias reload='source ~/.config/fish/config.fish'
alias please='sudo'
alias ssh='env TERM=xterm-256color ssh'

function mkcd
    mkdir -p $argv[1]
    and cd $argv[1]
end
