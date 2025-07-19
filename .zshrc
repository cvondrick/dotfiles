umask 0077

export PATH="$HOME/.local/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"
#ZSH_THEME="minimal"
#ZSH_THEME="af-magic"
plugins=(git python git-prompt zsh-syntax-highlighting zsh-autosuggestions zoxide)

# z and zi for cd

DISABLE_UPDATE_PROMPT=true # no auto-updates on shell launch

# export PYTHON_AUTO_VRUN=true
# export PYTHON_VENV_NAME=dev

source $ZSH/oh-my-zsh.sh

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
ZSH_HIGHLIGHT_PATTERNS+=('rm -r' 'fg=white,bold,bg=red')

ZSH_AUTOSUGGEST_STRATEGY=(completion)

ZSH_THEME_GIT_PROMPT_CACHE=0
ZSH_THEME_GIT_PROMPT_BRANCH=""
ZSH_THEME_GIT_PROMPT_BEHIND="%{$fg_bold[magenta]%}%{↓%G%}"
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg_bold[magenta]%}%{↑%G%}"

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
  PROMPT='%m: %2~ ❯ '
  
  # PATH for neovim
  export PATH="/proj/vondrick/carl/neovim/nvim-linux64/bin:$PATH"
  
  # Environment variables
  export HF_HOME=/proj/vondrick/carl/huggingface
  export UV_CACHE_DIR=/proj/vondrick8/carl/uv/cache
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  
  # Conditional vim alias (check if nvim is available)
  nvim --help > /dev/null 2>&1
  if [ $? -eq 0 ]; then
      alias vim='nvim'
      export EDITOR='nvim'
  fi
else
  export EDITOR='nvim'
  alias vim='nvim'
  PROMPT='%2~ ❯ '
fi

# FZF configuration (for both SSH and local sessions)
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
  export FZF_TMUX=1
  export FZF_TMUX_OPTS='-p80%,60%'
fi

#setopt promptsubst
#PS1=$'%{\e(0%}${(r:$COLUMNS::q:)}%{\e(B%}'$PS1

alias kitten='/Applications/kitty.app/Contents/MacOS/kitten'

alias python="python3"

alias btop="btop -lc"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

#. "$HOME/.local/bin/env"
