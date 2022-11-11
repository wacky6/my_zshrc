# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=~/my_zshrc/

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
#ZSH_THEME="robbyrussell"
ZSH_THEME="wacky"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
#ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(battery cp colored-man-pages colorize \
         dircycle encode64 jsontools extract \
         common-aliases gitfast)

# User configuration

# Unset precmd_functions to avoid concatenation if we source ~/.zshrc
precmd_functions=( )

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

alias js-bin="~/git/js-bin/js-bin"

export LC_ALL="en_US.UTF-8"

# Git shortcuts
alias gs="git status"
alias gd="git diff"
alias gdc="git diff --cached"
alias gds="git diff --staged"
alias gcb="git checkout -b"

# A hacky way to do diff against upstream with master/main migration.
# This prefers main (if it exists) over master.
function gdu {
    if git rev-parse --verify origin/main ; then
        git diff origin/main
    else
        git diff origin/master
    fi
}

# Intelligent graphical session switching.
# Automatically detects CRD / local session if that's relevant.
function _clever_display() {
    PROBED=$( command switch-graphical-session current 2>/dev/null )
    if [[ "$PROBED" =~ "local" ]]; then
        export DISPLAY=:1
    elif [[ "$PROBED" =~ "crd" ]]; then
        export DISPLAY=:20
    fi
}
precmd_functions+=(_clever_display)

# Source localrc
[ -f ~/.localrc ] && source ~/.localrc

# Declare hooks for RC files
wacky_theme_left_functions=( )
wacky_theme_right_functions=( )

# Pull in env specific RC files if .localrc declared them.
for rc in ${WACKY_ADDITIONAL_RC:-} ; do
    ADDITIONAL_RC=${ZSH_CUSTOM}rc/${rc}
    [ -f "$ADDITIONAL_RC" ] && source "$ADDITIONAL_RC" || echo "WARN: Additional rc \"$rc\" isn't found"
done
unset WACKY_ADDITIONAL_RC

# Check localrc is up-to-date with remote.
# Assumes zsh-sync is configured by zsh script from wacky6/ok-deploy
ZSHRC_DIR=$( dirname $( readlink -f $HOME/.zshrc ) )
CUR_COMMIT_TIME=$( cd $ZSHRC_DIR && git show master -s --format='%ct' || echo 0 )
UPSTREAM_COMMIT_TIME=$( cd $ZSHRC_DIR && git show origin/master -s --format='%ct' || echo 0 )
if [ $UPSTREAM_COMMIT_TIME -gt $CUR_COMMIT_TIME ] ; then
  print -rP ""
  print -rP "%K{160}Warning: Local zshrc is out-of-sync. Please check local changes.%F{231}%f%k"
  print -rP "%F{228}   Local commit is: $( git show master -s --format='%ci' )%f"
  print -rP "%F{228}  Remote commit is: $( git show origin/master -s --format='%ci' )%f"
  print -rP ""
fi

