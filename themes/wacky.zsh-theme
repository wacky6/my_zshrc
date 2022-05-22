#!/usr/bin/env zsh
# Modified from https://github.com/eendroroy/alien
# Original theme uses GPLv3

_is_git(){
  if [[ $(git branch 2>/dev/null) != "" ]]; then echo 1 ; else echo 0 ; fi
}

__wacky_git_branch() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || \
  ref=$(git rev-parse --short HEAD 2> /dev/null) || return false;
  echo " $B⑃$b ${ref#refs/heads/} ";
  return true;
}

_vcs_info(){
  if [[ $(_is_git) == 1 ]]; then
    __wacky_git_branch;
  else
    echo "";
  fi
}

__storage_info(){
  fs=`df -h . | tail -1 | awk '{print $1}' | sed "s|\.|•|g" `;
  size=`df -h . | tail -1 | awk '{print $2}' | sed "s|\.|•|g" `;
  used=`df -h . | tail -1 | awk '{print $3}' | sed "s|\.|•|g" `;
  usedp=`df -h . | tail -1 | awk '{print $5}' | sed "s|\.|•|g" `;
  free=`df -h . | tail -1 | awk '{print $4}' | sed "s|\.|•|g" `;
  echo "💾 $fs - F:$free U:$used T:$size";
}

__tty_id(){
  tty_id=()
  if [ -n "$STY" ]; then
    tty_id+=( screen.$( echo $STY | cut -f1 -d"." )  )
  fi
  if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$COCKPIT_REMOTE_PEER" ] || [ -n "$VSCODE_PROXY_URI" ]; then
    tty_id+=( $( hostname -s ) )
  fi
  echo ${(j:/:)tty_id}
}

__battery_stat(){
  __os=`uname`;
  if [[ $__os = "Linux" ]]; then
    if which upower > /dev/null ; then
      __bat_power=`upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep state | awk '{print $2}'`;
      __bat_power_ind="";
      if [[ $__bat_power = "charging" ]]; then __bat_power_ind="⇡";
      elif [[ $__bat_power = "discharging" ]]; then __bat_power_ind="⇣";
      elif [[ $__bat_power = "fully-charged" ]]; then __bat_power_ind="⌀";
      fi
      __bat_per=`upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep percentage | awk '{print $2}' | sed "s|%||g"`;
      if [[ -n $__bat_per ]]; then
        echo " ${__bat_power_ind}${__bat_per} ";
      fi
    fi
  elif [[ $__os = "Darwin" ]]; then
    __bat_power=`pmset -g batt | tail -1 | awk '{print $4}' | tr -d "%;"`;
    __bat_power_ind="";
    if [[ $__bat_power = "charging" ]]; then __bat_power_ind="⇡";
    elif [[ $__bat_power = "discharging" ]]; then __bat_power_ind="⇣";
    elif [[ $__bat_power = "finishing" ]]; then __bat_power_ind="⌀";
    elif [[ $__bat_power = "charged" ]]; then __bat_power_ind="⌀";
    fi
       __bat_per=`pmset -g batt | tail -1 | awk '{print $3}' | tr -d "%;"`
    if [[ -n $__bat_per ]]; then
      echo " ${__bat_per}${__bat_power_ind} ";
    fi
  else
    : ;
  fi
}

__date_str(){
  echo `date "+%H:%M:%S"`
}

__last_status() {
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 0 ] ; then
    echo "%F{120}✓%f"
  else
    echo "%F{196}✗ ${EXIT_CODE}%f"
  fi
}

get_padding () {
  local STR=$1$2
  local ZERO='%([BSUbfksu]|([FK]|){*})'
  local LENGTH=${#${(S%%)STR//$~ZERO/}}

  local PADDING=$(( ${COLUMNS} - $LENGTH ))

  echo ${(l:$PADDING:: :)}
}

precmd() {
  # For xterm256 color codes:
  # see: https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg
  # user name:
  # %K{017}%F{254} %n %f%k\

  # __last_status must be called first to detect last exit code
  local LAST_STATUS=`__last_status`
  LEFT="\
%K{019} $LAST_STATUS %k\
%K{026}%F{255} %3~ %f%k\
%K{039}%F{018}$( _vcs_info )%k%f\
"

  RIGHT="\
%K{026}%F{252}$( __battery_stat )%f%k\
%K{019}%F{254}  $( __date_str ) %f%k\
%K{019}%F{220}%B ♈︎  %b%f%k\
"

  PADDING=`get_padding $LEFT $RIGHT`
  print ''
  print -rP $LEFT$PADDING$RIGHT
}

ZLE_RPROMPT_INDENT=0
PROMPT='%F{196}$( __tty_id )%f %F{228}%B>%b%f '
RPROMPT=''
