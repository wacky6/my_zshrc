#!/usr/bin/env zsh
# Modified from https://github.com/eendroroy/alien
# Original theme uses GPLv3

_is_git(){
  if [[ $(git branch 2>/dev/null) != "" ]]; then echo 1 ; else echo 0 ; fi
}

_git_branch() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || \
  ref=$(git rev-parse --short HEAD 2> /dev/null) || return false;
  echo " $B⑃$b ${ref#refs/heads/} ";
  return true;
}

_vcs_info(){
  if [[ $(_is_git) == 1 ]]; then
    _git_branch;
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

__ssh_client(){
  if [ -n "$SSH_CLIENT" ]; then
    echo $SSH_CLIENT | awk {'print $1 " "'};
  fi
}

__battery_stat(){
  __os=`uname`;
  if [[ $__os = "Linux" ]]; then
    if which upower > /dev/null ; then
      __bat_power=`upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep state | awk '{print $2}'`;
      __bat_power_ind="";
      if [[ $__bat_power = "charging" ]]; then __bat_power_ind="+";
      elif [[ $__bat_power = "discharging" ]]; then __bat_power_ind="-";
      elif [[ $__bat_power = "fully-charged" ]]; then __bat_power_ind="•";
      fi
      __bat_per=`upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep percentage | awk '{print $2}' | sed "s|%||g"`;
      if [[ -n $__bat_per ]]; then
        echo " | ${__bat_power_ind}${__bat_per}";
      fi
    fi
  fi
  if [[ $__os = "Darwin" ]]; then
    __bat_power=`pmset -g batt | tail -1 | awk '{print $4}' | tr -d "%;"`;
    __bat_power_ind="";
    if [[ $__bat_power = "charging" ]]; then __bat_power_ind="⇡";
    elif [[ $__bat_power = "discharging" ]]; then __bat_power_ind="⇣";
    elif [[ $__bat_power = "finishing" ]]; then __bat_power_ind="⚡︎";
    elif [[ $__bat_power = "charged" ]]; then __bat_power_ind="⚡︎";
    fi
       __bat_per=`pmset -g batt | tail -1 | awk '{print $3}' | tr -d "%;"`
    if [[ -n $__bat_per ]]; then
      echo "${__bat_per}${__bat_power_ind}";
    fi
  fi
}

__date_str(){
  echo `date "+%H:%M:%S"`
}

wacky_prompts(){
  # For xterm256 color codes:
  # see: https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg
 
  PROMPT='
%K{017}%F{221}%B ♈︎ %b%f%k\
%K{017} %(?.%F{157}✓%f.%F{196}✗%f) %k\
%K{017}%F{254} $( __date_str ) %f%k\
%K{018}%F{252} $( __battery_stat ) %f%k\
%K{026}%F{229} %n %f%k\
%K{045}%F{019} %3~ %f%k\
%K{240}%F{254}$( _vcs_info )%k%f
%F{228}%B>%b%f '
  
  RPROMPT=""
}

wacky_prompts

