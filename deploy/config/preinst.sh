#!/bin/bash
if [ "$(which vnc-web)" != "" ] && [ "$1" == "install" ]; then
  echo "The command \"vnc-web\" is already present. Can not install this."
  echo "File: \"$(which vnc-web)\""
  exit 1
fi
exit 0
