#!/bin/bash
function undo_changes(){
  /usr/local/bin/vnc-web -d >/dev/null 2>&1
  exit 1
}
if [ -f "/usr/local/bin/vnc-web" ]; then
  echo "Build vnc-web service ..."
  /usr/local/bin/vnc-web -e >/dev/null 2>&1
  [ $? -ne 0 ] && undo_changes
fi
exit 0
