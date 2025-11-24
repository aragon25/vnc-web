#!/bin/bash
##############################################
##                                          ##
##  vnc-web                                 ##
##                                          ##
##############################################

#get some variables
SCRIPT_TITLE="vnc-web"
SCRIPT_VERSION="1.3"
SCRIPTDIR="$(readlink -f "$0")"
SCRIPTNAME="$(basename "$SCRIPTDIR")"
SCRIPTDIR="$(dirname "$SCRIPTDIR")"
CONFIGFILE="/etc/vnc-web/vnc.conf"
PASSWDFILE="/etc/vnc-web/vncpasswd.pass"
CERTFILE="/etc/vnc-web/sslcert.cert"
KEYFILE="/etc/vnc-web/sslcert.key"
NGINXSITENAME="vnc-web"
WEBSOCKIFY="$(which websockify)"
NOVNCINDEXPATH="/usr/local/share/novncweb/vnc.html"
NOVNCINDEX="$(basename "$NOVNCINDEXPATH")"
NOVNCDIR="$(dirname "$NOVNCINDEXPATH")"
X11VNC="$(which x11vnc)"
PIDFILE="/run/vnc-web-service.pid"
EXITCODE=0

#!!!RUN RESTRICTIONS!!!
#only for raspberry pi (rpi5|rpi4|rpi3|all) can combined!
raspi="all"
#only for Raspbian OS (bookworm|bullseye|all) can combined!
rasos="bookworm|bullseye"
#only for cpu architecture (i386|armhf|amd64|arm64) can combined!
cpuarch=""
#only for os architecture (32|64) can NOT combined!
bsarch=""
#this aptpaks need to be installed!
aptpaks=( x11vnc websockify nginx openssl )

#check commands
for i in "$@"
do
  case $i in
    --service)
    [ "$CMD" == "" ] && CMD="service" || CMD="help"
    shift # past argument
    ;;
    -p=*)
    PASS=${i#-p=}
    [ "$CMD" == "" ] && CMD="password" || CMD="help"
    shift # past argument
    ;;
    --password=*)
    PASS=${i#--password=}
    [ "$CMD" == "" ] && CMD="password" || CMD="help"
    shift # past argument
    ;;
    -c|--check_ssl)
    [ "$CMD" == "" ] && CMD="check_ssl" || CMD="help"
    shift # past argument
    ;;
    -r|--read_paswd)
    [ "$CMD" == "" ] && CMD="read_paswd" || CMD="help"
    shift # past argument
    ;;
    -e|--enable)
    [ "$CMD" == "" ] && CMD="enable" || CMD="help"
    shift # past argument
    ;;
    -d|--disable)
    [ "$CMD" == "" ] && CMD="disable" || CMD="help"
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

function do_check_start() {
  #check if superuser
  if [ $UID -ne 0 ]; then
    echo "Please run this script with Superuser privileges!"
    exit 1
  fi
  #check if service is already running or create pidfile if needed
  if [[ "$CMD" =~ "service" ]] && [ -e "$PIDFILE" ] && ps -p $(<"$PIDFILE") >/dev/null 2>&1; then
    echo "Service is already running!"
    exit 1
  elif [ "$CMD" == "service" ]; then
    echo $$ > "$PIDFILE"
  fi
  #check if raspberry pi 
  if [ "$raspi" != "" ]; then
    raspi_v="$(tr -d '\0' 2>/dev/null < /proc/device-tree/model)"
    local raspi_res="false"
    [[ "$raspi_v" =~ "Raspberry Pi" ]] && [[ "$raspi" =~ "all" ]] && raspi_res="true"
    [[ "$raspi_v" =~ "Raspberry Pi 3" ]] && [[ "$raspi" =~ "rpi3" ]] && raspi_res="true"
    [[ "$raspi_v" =~ "Raspberry Pi 4" ]] && [[ "$raspi" =~ "rpi4" ]] && raspi_res="true"
    [[ "$raspi_v" =~ "Raspberry Pi 5" ]] && [[ "$raspi" =~ "rpi5" ]] && raspi_res="true"
    if [ "$raspi_res" == "false" ]; then
      echo "This Device seems not to be an Raspberry Pi ($raspi)! Can not continue with this script!"
      exit 1
    fi
  fi
  #check if raspbian
  if [ "$rasos" != "" ]
  then
    rasos_v="$(lsb_release -d -s 2>/dev/null)"
    [ -f /etc/rpi-issue ] && rasos_v="Raspbian ${rasos_v}"
    local rasos_res="false"
    [[ "$rasos_v" =~ "Raspbian" ]] && [[ "$rasos" =~ "all" ]] && rasos_res="true"
    [[ "$rasos_v" =~ "Raspbian" ]] && [[ "$rasos_v" =~ "bullseye" ]] && [[ "$rasos" =~ "bullseye" ]] && rasos_res="true"
    [[ "$rasos_v" =~ "Raspbian" ]] && [[ "$rasos_v" =~ "bookworm" ]] && [[ "$rasos" =~ "bookworm" ]] && rasos_res="true"
    if [ "$rasos_res" == "false" ]; then
      echo "You need to run Raspbian OS ($rasos) to run this script! Can not continue with this script!"
      exit 1
    fi
  fi
  #check cpu architecture
  if [ "$cpuarch" != "" ]; then
    cpuarch_v="$(dpkg --print-architecture 2>/dev/null)"
    if [[ ! "$cpuarch" =~ "$cpuarch_v" ]]; then
      echo "Your CPU Architecture ($cpuarch_v) is not supported! Can not continue with this script!"
      exit 1
    fi
  fi
  #check os architecture
  if [ "$bsarch" == "32" ] || [ "$bsarch" == "64" ]; then
    bsarch_v="$(getconf LONG_BIT 2>/dev/null)"
    if [ "$bsarch" != "$bsarch_v" ]; then
      echo "Your OS Architecture ($bsarch_v) is not supported! Can not continue with this script!"
      exit 1
    fi
  fi
  #check apt paks
  local apt
  local apt_res
  IFS=$' '
  if [ "${#aptpaks[@]}" != "0" ]; then
    for apt in ${aptpaks[@]}; do
      [[ ! "$(dpkg -s $apt 2>/dev/null)" =~ "Status: install" ]] && apt_res="${apt_res}${apt}, "
    done
    if [ "$apt_res" != "" ]; then
      echo "Not installed apt paks: ${apt_res%?%?}! Can not continue with this script!"
      exit 1
    fi
  fi
  unset IFS
   #check config files integrity
  [[ ! $(file -b --mime-type "$(readlink -f "$CONFIGFILE")" 2>/dev/null) =~ "text" ]] && config_write_all
}

function config_read(){ # path, key, defaultvalue -> value
  local val=$( (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-)
  #val=$(echo "${val}" | sed 's/ *$//g' | sed 's/^ *//g')
  val=$(echo "$val" | xargs)
  [ "${val}" == "__UNDEFINED__" ] && val="$3"
  printf -- "%s" "${val}"
}

function config_write(){ # path, key, value
  [ ! -e "$1" ] && touch "$1"
  sed -i "/^$(echo $2 | sed -e 's/[]\/$*.^[]/\\&/g').*$/d" "$1"
  echo "$2=$3" >> "$1"
}

function config_read_all(){
  CONFIG_PORT=$(config_read "$CONFIGFILE" CONFIG_PORT "8090")
  CONFIG_NO_SSL=$(config_read "$CONFIGFILE" CONFIG_NO_SSL "false")
  CONFIG_CERT_FILE=$(config_read "$CONFIGFILE" CONFIG_CERT_FILE "$CERTFILE")
  CONFIG_KEY_FILE=$(config_read "$CONFIGFILE" CONFIG_KEY_FILE "$KEYFILE")
}

function config_write_all(){
  rm -f "$CONFIGFILE" >/dev/null 2>&1
  mkdir -p "$(dirname ""$CONFIGFILE"")" >/dev/null 2>&1
  [ -z $CONFIG_PORT ] && CONFIG_PORT="8090"
  config_write "$CONFIGFILE" CONFIG_PORT "$CONFIG_PORT"
  [ -z $CONFIG_NO_SSL ] && CONFIG_NO_SSL="false"
  config_write "$CONFIGFILE" CONFIG_NO_SSL "$CONFIG_NO_SSL"
  [ -z $CONFIG_CERT_FILE ] && CONFIG_CERT_FILE="$CERTFILE"
  config_write "$CONFIGFILE" CONFIG_CERT_FILE "$CONFIG_CERT_FILE"
  [ -z $CONFIG_KEY_FILE ] && CONFIG_KEY_FILE="$KEYFILE"
  config_write "$CONFIGFILE" CONFIG_KEY_FILE "$CONFIG_KEY_FILE"
}

function delete_user_services() {
  local user_uid
  for user_uid in $(loginctl list-users --no-legend | awk '{print $1}'); do
    sudo -u "#$user_uid" XDG_RUNTIME_DIR="/run/user/$user_uid" systemctl --user stop vncxsetfix.service >/dev/null 2>&1
  done
  systemctl --global disable vncxsetfix >/dev/null 2>&1
  if [ -e "/lib/systemd/user/vncxsetfix.service" ]; then
    rm -f "/lib/systemd/user/vncxsetfix.service" >/dev/null 2>&1
  fi
  for user_uid in $(loginctl list-users --no-legend | awk '{print $1}'); do
    sudo -u "#$user_uid" XDG_RUNTIME_DIR="/run/user/$user_uid" systemctl --user daemon-reload >/dev/null 2>&1
  done
}

function create_user_services() {
  local user_uid
  if [ ! -e "/lib/systemd/user/vncxsetfix.service" ]; then
    cat <<EOF | sudo tee "/lib/systemd/user/vncxsetfix.service" >/dev/null 2>&1
[Unit]
Description=DPMS fix for VNC and xset

[Service]
Type=simple
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/vncxsetfix --service
Restart=always

[Install]
WantedBy=default.target
Alias=vncxsetfix.service
EOF
  fi
  systemctl --global enable vncxsetfix >/dev/null 2>&1
  for user_uid in $(loginctl list-users --no-legend | awk '{print $1}'); do
    sudo -u "#$user_uid" XDG_RUNTIME_DIR="/run/user/$user_uid" systemctl --user daemon-reload >/dev/null 2>&1
    sudo -u "#$user_uid" XDG_RUNTIME_DIR="/run/user/$user_uid" systemctl --user restart vncxsetfix.service >/dev/null 2>&1
  done
}

function check_service() {
  if ! systemctl list-unit-files 2>/dev/null | grep -q "$1"; then
    printf -- "%s\n" "__NOTFOUND__"
    return
  elif systemctl is-active "$1" >/dev/null 2>&1; then
    printf -- "%s\n" "__ACTIVE__"
  elif systemctl is-failed "$1" >/dev/null 2>&1; then
    printf -- "%s\n" "__FAILED__"
  else
    printf -- "%s\n" "__INACTIVE__"
  fi
  if systemctl is-enabled "$1" >/dev/null 2>&1; then
    printf -- "%s\n" "__ENABLED__"
  else
    printf -- "%s\n" "__DISABLED__"
  fi
}

function delete_vnc_service() {
  if [ -f "/lib/systemd/system/vnc-web.service" ]; then
    systemctl stop vnc-web >/dev/null 2>&1
    systemctl disable vnc-web >/dev/null 2>&1
    rm -f "/lib/systemd/system/vnc-web.service" >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
  fi
  rm -f "/etc/nginx/sites-available/$NGINXSITENAME"
  rm -f "/etc/nginx/sites-enabled/$NGINXSITENAME"
  systemctl stop nginx >/dev/null 2>&1
  systemctl start nginx >/dev/null 2>&1
}

function create_vnc_service() {
  if [ ! -f "/lib/systemd/system/vnc-web.service" ]; then
    cat <<EOF | sudo tee /lib/systemd/system/vnc-web.service >/dev/null 2>&1
[Unit]
Description=vnc-web service
After=display-manager.service

[Service]
Type=simple
ExecStart=$SCRIPTDIR/$SCRIPTNAME --service
User=root
PIDFile=$PIDFILE
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
Alias=vnc-web.service
EOF
    systemctl daemon-reload >/dev/null 2>&1
  fi
  local service_status="$(check_service vnc-web)"
  [[ "$service_status" =~ "__DISABLED__" ]] && systemctl enable vnc-web >/dev/null 2>&1
  [[ ! "$service_status" =~ "__ACTIVE__" ]] && systemctl start vnc-web >/dev/null 2>&1 || systemctl restart vnc-web >/dev/null 2>&1
}

function disable_nginx_vncweb() {
  if [ -e "/etc/nginx/sites-enabled/$NGINXSITENAME" ]; then
    rm -f "/etc/nginx/sites-enabled/$NGINXSITENAME"
    systemctl stop nginx >/dev/null 2>&1
    systemctl start nginx >/dev/null 2>&1
  fi
}

function enable_nginx_vncweb() {
  local rebuild_conf="no"
  [ "$1" == "force" ] && rebuild_conf="yes"
  if ! grep -q "listen $CONFIG_PORT" "/etc/nginx/sites-available/$NGINXSITENAME" >/dev/null 2>&1 || \
     ! grep -q "index $NOVNCINDEX" "/etc/nginx/sites-available/$NGINXSITENAME" >/dev/null 2>&1 || \
     ! grep -q "root $NOVNCDIR" "/etc/nginx/sites-available/$NGINXSITENAME" >/dev/null 2>&1; then
    rebuild_conf="yes"
  fi
  if [ "${CONFIG_NO_SSL}" != "true" ]; then
    if ! grep -q "ssl_certificate $CONFIG_CERT_FILE" "/etc/nginx/sites-available/$NGINXSITENAME" >/dev/null 2>&1 || \
       ! grep -q "ssl_certificate_key $CONFIG_KEY_FILE" "/etc/nginx/sites-available/$NGINXSITENAME" >/dev/null 2>&1; then
      rebuild_conf="yes"
    fi
  elif grep -q "ssl on" "/etc/nginx/sites-available/$NGINXSITENAME" >/dev/null 2>&1; then
      rebuild_conf="yes"
  fi
  if [ "${rebuild_conf}" == "yes" ]; then
    rm -f "/etc/nginx/sites-available/$NGINXSITENAME"
    rm -f "/etc/nginx/sites-enabled/$NGINXSITENAME"
    cat > "/etc/nginx/sites-available/$NGINXSITENAME" << EOF
  server {
    listen $CONFIG_PORT default_server;
EOF
    if [ "${CONFIG_NO_SSL}" != "true" ]; then
      cat >> "/etc/nginx/sites-available/$NGINXSITENAME" << EOF
    ssl on;
    ssl_certificate $CONFIG_CERT_FILE;
    ssl_certificate_key $CONFIG_KEY_FILE;
    error_page 497 301 =307 https://\$host:\$server_port\$request_uri;
EOF
    fi
    cat >> "/etc/nginx/sites-available/$NGINXSITENAME" << EOF
    gzip on;
    gzip_proxied any;
    gzip_types text/plain text/xml text/css application/x-javascript application/javascript;
    gzip_vary on;

    location / {
      index $NOVNCINDEX;
      root $NOVNCDIR;
      add_header Cache-Control no-cache;
    }

    location /websockify {
      proxy_pass http://127.0.0.1:6081;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "Upgrade";
      proxy_set_header Host \$host;
      add_header Cache-Control no-cache;
      proxy_buffering off;
      client_max_body_size 10240M;
      client_body_buffer_size 4m;
      proxy_connect_timeout 7d;
      proxy_send_timeout 7d;
      proxy_read_timeout 7d;
    }
  }
EOF
  fi
  if [ ! -e "/etc/nginx/sites-enabled/$NGINXSITENAME" ]; then
    ln -f -s "/etc/nginx/sites-available/$NGINXSITENAME" "/etc/nginx/sites-enabled/$NGINXSITENAME"
    [[ "$(check_service nginx)" =~ "__ACTIVE__" ]] && systemctl stop nginx >/dev/null 2>&1
  fi
  [[ ! "$(check_service nginx)" =~ "__ACTIVE__" ]] && systemctl start nginx >/dev/null 2>&1
  [[ "$(check_service nginx)" =~ "__FAILED__" ]] && EXITCODE=1
}

function cmd_service() {
  local websockify_ssl
  local x11vnc_pid
  local websockify_pid
  local force_rebuild
  if [ "${CONFIG_NO_SSL}" != "true" ]; then
    local cert_hostname="$(openssl x509 -checkhost "$(hostname)" -noout -in "${CONFIG_CERT_FILE}" 2>/dev/null)"
    if ! openssl rsa -check -in ${CONFIG_KEY_FILE} >/dev/null 2>&1 && [ "${CONFIG_KEY_FILE}" != "${KEYFILE}" ]; then
      echo "certificate key file not valid! Using default selfsigned certificate instead!"
      CONFIG_CERT_FILE="${CERTFILE}"
      CONFIG_KEY_FILE="${KEYFILE}"
    fi
    if [[ ! ${cert_hostname} =~ "does match" ]] && [ "${CONFIG_CERT_FILE}" != "${CERTFILE}" ]; then
      echo "certificate file does not match host! Using default selfsigned certificate instead!"
      CONFIG_CERT_FILE="${CERTFILE}"
      CONFIG_KEY_FILE="${KEYFILE}"
    fi
    if [ "${CONFIG_CERT_FILE}" == "${CERTFILE}" ] && [ "${CONFIG_KEY_FILE}" == "${KEYFILE}" ]; then
      cert_hostname="$(openssl x509 -checkhost "$(hostname)" -noout -in "${CONFIG_CERT_FILE}" 2>/dev/null)"
      if ! openssl rsa -check -in ${CONFIG_KEY_FILE} >/dev/null 2>&1 || [[ ! ${cert_hostname} =~ "does match" ]]; then
        echo "default selfsigned certificate not valid! Rebuild now..."
        rm -f ${CONFIG_CERT_FILE}
        rm -f ${CONFIG_KEY_FILE}
        openssl req -x509 -newkey rsa:4096 -out ${CONFIG_CERT_FILE} -keyout ${CONFIG_KEY_FILE} -sha256 -days 3650 -nodes -subj "/CN=$(hostname)" >/dev/null 2>&1
        force_rebuild="force"
      fi
    fi
    websockify_ssl="--cert=${CONFIG_CERT_FILE} --key=${CONFIG_KEY_FILE}"
  fi
  enable_nginx_vncweb $force_rebuild
  while [ -f "$PIDFILE" ] && [ $EXITCODE -eq 0 ]; do
    if ! ps -p $x11vnc_pid >/dev/null 2>&1; then
      [ ! -f "$PASSWDFILE" ] && "$X11VNC" -storepasswd "raspi" "$PASSWDFILE"
      "$X11VNC" -env FD_XDM=1 -auth guess -forever -loop -noxdamage -repeat -display :0 -rfbauth "$PASSWDFILE" -rfbport 5908 -shared -localhost -norc -quiet &
      x11vnc_pid=$!
    fi
    if ! ps -p $websockify_pid >/dev/null 2>&1; then
      "$WEBSOCKIFY" ${websockify_ssl} --web $NOVNCDIR 6081 localhost:5908 &
      websockify_pid=$!
    fi
    [[ ! "$(check_service nginx)" =~ "__ACTIVE__" ]] && systemctl start nginx >/dev/null 2>&1
    [[ "$(check_service nginx)" =~ "__FAILED__" ]] && EXITCODE=1
    sleep 10
  done
  kill $x11vnc_pid >/dev/null 2>&1
  kill $websockify_pid >/dev/null 2>&1
  disable_nginx_vncweb
}

function cmd_enable() {
  create_vnc_service
  create_user_services
  echo "vnc-web is now enabled."
}

function cmd_disable() {
  delete_user_services
  delete_vnc_service
  echo "vnc-web is now disabled."
}

function cmd_check_ssl() {
  if [ "${CONFIG_NO_SSL}" != "true" ]; then
    if [ "${CONFIG_CERT_FILE}" == "${CERTFILE}" ] && [ "${CONFIG_KEY_FILE}" == "${KEYFILE}" ]; then
      echo "Default SSL config active. (OK)"
    else
      local cert_hostname="$(openssl x509 -checkhost "$(hostname)" -noout -in "${CONFIG_CERT_FILE}" 2>/dev/null)"
      if ! openssl rsa -check -in ${CONFIG_KEY_FILE} >/dev/null 2>&1; then
        echo "Custom SSL config active. (KEY_ERROR)"
        echo "Using default certificate instead."
      elif [[ ! ${cert_hostname} =~ "does match" ]]; then
        echo "Custom SSL config active. (CERT_HOSTNAME_ERROR)"
        echo "Using default certificate instead."
      else
        echo "Custom SSL config active. (OK)"
      fi
    fi
  else
    echo "SSL is disabled by config!"
  fi
}

function cmd_password() {
  rm -f "$PASSWDFILE"
  "$X11VNC" -storepasswd "$PASS" "$PASSWDFILE"
  echo "vnc-web password changed."
}

function cmd_read_paswd() {
  local password=$("$X11VNC" -showrfbauth "$PASSWDFILE" 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i~/pass:/)print $(i+1)}')
  [ "${password}" == "raspi" ] && password=""
  [ "${password}" == "" ] && echo "pass: raspi (default)" || echo "pass: $password"
}

function cmd_print_version() {
  echo "$SCRIPT_TITLE v$SCRIPT_VERSION"
}

function cmd_print_help() {
  echo "Usage: $(basename ""$0"") [OPTION]"
  echo "$SCRIPT_TITLE v$SCRIPT_VERSION"
  echo " "
  echo "A VNC server setup for Raspberry Pi with noVNC web" 
  echo "client access via browser including xsetfix functionality."
  echo " "
  echo "Current config:"
  echo "Port: $CONFIG_PORT"
  if [ "${CONFIG_NO_SSL}" != "true" ]; then
    echo "SSL: yes"
    echo "SSL-Cert: $CONFIG_CERT_FILE"
    echo "SSL-Key: $CONFIG_KEY_FILE"
    echo "Website access: https://$(hostname):$CONFIG_PORT/"
  else
    echo "SSL: no"
    echo "Website access: http://$(hostname):$CONFIG_PORT/"
  fi
  echo " "
  echo "-p={password}           changes the password for x11vncserver"
  echo "--password={password}   same as -p={password}"
  echo "-r, --read_paswd        prints decrypted saved password"
  echo "-c, --check_ssl         checks ssl-cert and ssl-key"
  echo "-e, --enable            enables x11vncserver and website"
  echo "-d, --disable           disables x11vncserver and website"
  echo "-v, --version           print version info and exit"
  echo "-h, --help              print this help and exit"
  echo " "
  echo "Author: aragon25 <aragon25.01@web.de>"
}

[ "$CMD" != "version" ] && [ "$CMD" != "help" ] &&  do_check_start 
config_read_all
[[ "$CMD" == "version" ]] && cmd_print_version
[[ "$CMD" == "help" ]] && cmd_print_help
[[ "$CMD" == "service" ]] && cmd_service
[[ "$CMD" == "enable" ]] && cmd_enable
[[ "$CMD" == "disable" ]] && cmd_disable
[[ "$CMD" == "password" ]] && cmd_password
[[ "$CMD" == "read_paswd" ]] && cmd_read_paswd
[[ "$CMD" == "check_ssl" ]] && cmd_check_ssl

exit $EXITCODE