#!/bin/bash
##############################################
##                                          ##
##  vncxsetfix                              ##
##                                          ##
##############################################

#get some variables
export LC_ALL=C
export LANG=C
USER_ID="$(id -u)"
USER_NAME="$(id -un)"
SCRIPT_TITLE="vncxsetfix"
SCRIPT_VERSION="1.3"
SCRIPTDIR="$(readlink -f "$0")"
SCRIPTNAME="$(basename "$SCRIPTDIR")"
SCRIPTDIR="$(dirname "$SCRIPTDIR")"
EXITCODE=0

#check commands
for i in "$@"
do
  case $i in
    --service)
    [ "$CMD" == "" ] && CMD="service" || CMD="help"
    shift # past argument
    ;;
    -v|--version)
    [ "$CMD" == "" ] && CMD="version" || CMD="help"
    shift # past argument
    ;;
    -h|--help)
    CMD="help"
    shift # past argument
    ;;
    *)
    if [ "$i" != "" ]
    then
      echo "Unknown option: $i"
      exit 1
    fi
    ;;
  esac
done
[ "$CMD" == "" ] && CMD="help"

get_xsession_user() {
  local entry
  local test
  local result
  IFS=$'\n'
  test=($(w -hs 2>/dev/null))
  if [ "${#test[@]}" != "0" ]; then
    for entry in ${test[@]}; do
      [[ "$entry" =~ " :0 " ]] && result="$(echo "$entry" | cut -d' ' -f1)"
    done
  fi
  [ "$result" != "" ] && printf -- "%s\n" "$result"
  unset IFS
}

function cmd_main() {
  local xsetresult=""
  local xprintidleresult=0
  local standby_time=0
  local suspend_time=0
  local off_time=0
  local docheck="yes"
  while true; do
    if [ "$(get_xsession_user | tail -1)" == "$USER_NAME" ]; then
      xprintidleresult=$(xprintidle 2>/dev/null)
      xprintidleresult=$((${xprintidleresult}/1000))
      xsetresult="$(xset q 2>/dev/null)"
      if [[ "$xsetresult" =~ "DPMS is Enabled" ]]; then
        standby_time=$(echo "$xsetresult" | awk '{for(i=1;i<=NF;i++) if($i=="Standby:") print $(i+1)}' | tail -1)
        suspend_time=$(echo "$xsetresult" | awk '{for(i=1;i<=NF;i++) if($i=="Suspend:") print $(i+1)}' | tail -1)
        off_time=$(echo "$xsetresult" | awk '{for(i=1;i<=NF;i++) if($i=="Off:") print $(i+1)}' | tail -1)
        [ -z "$off_time" ] && off_time=0
        [ -z "$suspend_time" ] && suspend_time=0
        [ -z "$standby_time" ] && standby_time=0
        if (( $xprintidleresult >= $off_time )) 2>/dev/null && (( $off_time > 0 )) 2>/dev/null; then
          [ "$docheck" != "off" ] && xset dpms force off
          docheck="off"
        elif (( $xprintidleresult >= $suspend_time )) 2>/dev/null && (( $suspend_time > 0 )) 2>/dev/null; then
          [ "$docheck" != "suspend" ] && xset dpms force suspend
          docheck="suspend"
        elif (( $xprintidleresult >= $standby_time )) 2>/dev/null && (( $standby_time > 0 )) 2>/dev/null; then
          [ "$docheck" != "standby" ] && xset dpms force standby
          docheck="standby"
        else
          docheck="yes"
          [[ "$xsetresult" =~ "Monitor is Off" ]] && xset dpms force on
        fi
      else
        [[ "$xsetresult" =~ "Monitor is Off" ]] && xset dpms force on
        docheck="yes"
      fi
    else
      docheck="yes"
    fi
    sleep 20
  done
}

function cmd_print_version() {
  echo "$SCRIPT_TITLE v$SCRIPT_VERSION"
}

function cmd_print_help() {
  echo "Usage: $(basename ""$0"") [OPTION]"
  echo "$SCRIPT_TITLE v$SCRIPT_VERSION"
  echo " "
  echo "-v, --version           print version info and exit"
  echo "-h, --help              print this help and exit"
  echo " "
  echo "Only one option at same time is allowed!"
  echo " "
  echo "Author: aragon25 <aragon25.01@web.de>"
}

[[ "$CMD" == "version" ]] && cmd_print_version
[[ "$CMD" == "help" ]] && cmd_print_help
[[ "$CMD" == "service" ]] && cmd_main

exit $EXITCODE
