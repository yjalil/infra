# Oh-My-Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
  git
  gitfast
  last-working-dir
  common-aliases
  zsh-syntax-highlighting
  zsh-history-substring-search
)

ZSH_DISABLE_COMPFIX="true"
source $ZSH/oh-my-zsh.sh

# Unalias problematic
unalias rm 2>/dev/null || true
unalias lt 2>/dev/null || true

# PATH
export PATH="$HOME/.local/bin:$PATH"

# Locale
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Container greeting
echo "Infra DevContainer"
echo "Workspace: /workspace"
echo ""
echo "Quick commands:"
echo "  cd terraform && ./spin.sh workspace list"
echo "  ./spin.sh workspace new <env>"
echo "  ./spin.sh apply"
echo "  ./spin.sh destroy"
echo ""

# History (using mounted volume for persistence)
HISTFILE_DIR=/home/vscode/.zsh_history_dir
mkdir -p "$HISTFILE_DIR" 2>/dev/null
HISTFILE="$HISTFILE_DIR/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
[[ -f "$HISTFILE.LOCK" ]] && rm -f "$HISTFILE.LOCK"
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# Navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Completion
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
