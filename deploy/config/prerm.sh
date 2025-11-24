#!/bin/bash
if [ -f "/usr/local/bin/vnc-web" ]; then
  echo "Prepare to remove ..."
  /usr/local/bin/vnc-web -d >/dev/null 2>&1
fi
exit 0
