#!/bin/bash
#
# Author: Sherif Khaled
# Copyright (c) 2019.
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# This install-odoo.sh script automates many of the instrallation and configuration
# steps at
#    https://www.odoo.com/documentation/10.0/setup/install.html
#
# Eamples:-
# Install odoo version 10 and configure using server external IP address
# .\install-odoo.sh -v 10
#
# Install odoo version 10 and configure using hostname odoo.example.com
# .\install-odoo.sh -v 10 -s odoo.example.com
#
# Install odoo version 10 with a SSL certificate from Let's Encrypt using e-mail info@example.com:
# .\install-odoo.sh -v 10 -s odoo.example.com -e info@example.com
#
# Install odoo version 10 with specific port 8070
# .\install-odoo.sh -v 10 -s odoo.example.com -e info@example.com -r 8070
#
# Install odoo version 10 with postgres password and Master password
# .\install-odoo.sh -v 10 -s odoo.example.com -e info@example.com -r 8070 -p sql123 -P admin123
#
# Note: this script tested on ubuntu 16.4.
#

USAGE(){
  cat 1>&2 <<HERE
  Installer script for setting up odoo system.

  This script support odoo Version (10 ,11 ,12), also this script
  supports installation on cloud host or localhost.

  USAGE:
      odoo-install.sh [OPTIONS]

  OPTIONS (Install odoo system):

      -v    <version>          Install given version of odoo (e.g. '10.0') [required]
      -p    <admin password>   Password for odoo administrator [recommended]
      -P    <sql password>     setup password for postgresql   [recommended]
      -r    <server port>      spsifec server port
      -h                       Print help

  OPTIONS (support SSL)
      -s    <hostname>         Configure server with <hostname> [required]
      -e    <email>            E-mail for Let's Encrypt certbot [required]

  EXAMPLES

     setup odoo system

        .\install-odoo.sh -v 10
        .\install-odoo.sh -v 10 -s odoo.example.com -p 123
        .\install-odoo.sh -v 10 -s odoo.example.com -e info@example.com -p 123 -P sql123
        .\install-odoo.sh -v 10 -s odoo.example.com -e info@example.com -p 123 -P sql123 -r 8069

  SUPPORT:
      Source: https://github.com/Sherif-khaled/install-odoo
      Commnity: https://odoo-community.org/

HERE
}

main(){

 check_x64
 check_mem
 check_ubuntu 16.04

 get_ip
 HOST=$EXTERNAL_IP
 PORT=8069

  while builtin getopts "hv:p:P:r:s:e:" opt "${@}"; do
    case $opt in
      h)
        USAGE
        exit 0
        ;;

      v)
        VERSION=$OPTARG
        check_version $VERSION
        ;;
      p)
        PASS=$OPTARG
        check_admin_pass $PASS
        ;;
      P)
        SQL_PASS=$OPTARG
        check_sql_pass $SQL_PASS
        ;;
      r)
        PORT=$OPTARG
        check_port $PORT
        ;;
      s)
        HOST=$OPTARG
        check_host $HOST
        ;;
      e)
        EMAIL=$OPTARG
        check_email $EMAIL
        ;;

      :)
        err "Missing option argument for -$OPTARG"
        exit 1
        ;;

      \?)
        err "Invalid option: -$OPTARG" >&2
        usage
        ;;
    esac
  done
install_odoo
}



check_root() {
  if [ $EUID != 0 ]; then err "You must run this script as root."; fi
}

err(){
  echo "install-odoo.sh say: $1"
  exit 1
}
check_version(){
  ver=$1
  case $ver in
    9)
       return $ver
      ;;
    10)
       return $ver
      ;;
    11)
       return $ver
      ;;
    12 )
       return $ver
      ;;
    *)
       err "the script not supported this version $ver"
  esac

}
check_admin_pass(){
  if [ -z $1 ];then
    err "please enter the admin password"
  fi
}
check_sql_pass(){
  if [ -z $1 ];then
    err "please enter the postgresql password"
  fi
}
check_port(){
  if [ $1 -gt 8090 ] && [ $1 -lt 8060 ];then
    err "the port number must be between [8060] and [8090]"
  fi
}
check_host(){

  if [ -z $1 ];then
    err "please enter your hostname"
  fi

  DIG_IP=$(dig +short $1 | grep '^[.0-9]*$' | tail -n1)

  get_ip
  if [ -z "$DIG_IP" ]; then err "Unable to resolve $1 to an IP address using DNS lookup."; fi

  if [ "$DIG_IP" != "$EXTERNAL_IP" ]; then err "DNS lookup for $1 resolved to $DIG_IP but didn't match local $EXTERNAL_IP."; fi
}
get_ip(){
  EXTERNAL_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
}
check_email(){
  if [ -z $1 ];then
    err "please enter your email"
  fi
}
check_mem() {
  MEM=`grep MemTotal /proc/meminfo | awk '{print $2}'`
  MEM=$((MEM/1000))
  if (( $MEM < 2048 )); then err "Your server needs to have (at least) 2G of memory."; fi
}

check_ubuntu(){
  RELEASE=$(lsb_release -r | sed 's/^[^0-9]*//g')
  if [ "$RELEASE" != $1 ]; then err "You must run this command on Ubuntu $1 server."; fi
}

check_x64() {
  UNAME=`uname -m`
  if [ "$UNAME" != "x86_64" ]; then err "You must run this command on a 64-bit server."; fi
}
check_apache2() {
  if dpkg -l | grep -q apache2; then err "You must unisntall apache2 first"; fi
}
upgrade_system(){
  echo -e "\n---- Update Server ----"
  apt update
  apt dist-upgrade -y
}
configure_ufw(){
  service ufw start
  ufw allow ssh
  ufw allow $PORT/tcp
  ufw allow 80/tcp

  if [ ! -z $EMAIL ];then
  	ufw allow 443/tcp
  fi

  echo "y" | ufw enable $answer
}
install_dependencies(){
#REF  https://www.getopenerp.com/install-odoo-12-on-ubuntu-18-04/

  declare -a dependencies=("git" "postgresql" "postgresql-server-dev-9.5" "libzip-dev"
                           "libxml2-dev" "build-essential" "wget" "libxslt-dev" "libldap2-dev"
                           "libxslt1-dev" "libsasl2-dev" "libldap2-dev" "pkg-config" "libsasl2-dev"
                           "libtiff5-dev" "libjpeg8-dev" "libjpeg-dev" "zlib1g-dev" "node-less"
                           "libfreetype6-dev" "liblcms2-dev" "liblcms2-utils" "libwebp-dev"
                           "tcl8.6-dev" "tk8.6-dev" "libyaml-dev" "fontconfig")

 declare -a python_env=("python-pip" "python-all-dev" "python-dev" "python-setuptools" "python-tk")

 declare -a python3_env=("python3-pip" "python3-software-properties" "python3-all-dev" "python3-dev"
                         "python3-setuptools" "python3-tk" "python3-venv" "python3-wheel")

 for (( i = 0; i < ${#dependencies[@]} ; i++ )); do
     printf "\n**** Basic dependencies installing now: ${dependencies[$i]} *****\n\n"

     # Run each command in array
     eval "apt-get install ${dependencies[$i]} -y"
 done

 if [ $VERSION -eq 10 ] || [ $VERSION -eq 9 ];then

   for (( i = 0; i < ${#python_env[@]} ; i++ )); do
       printf "\n**** python env installing now: ${python_env[$i]} *****\n\n"

       # Run each command in array
       eval "apt-get install ${python_env[$i]} -y"
   done

elif [ $VERSION -eq 12 ] || [ $VERSION -eq 11 ];then
  for (( i = 0; i < ${#python3_env[@]} ; i++ )); do
      printf "\n**** python3 env Installing now : ${python3_env[$i]} *****\n\n"

      # Run each command in array
      eval "apt-get install ${python3_env[$i]} -y"
  done
fi
}
create_user(){
  #create postgresql user
  #createuser odoo10 -U postgres -dRS | printf '123456\n123456\n' | ./install-odoo.sh
#  su - postgres && createuser odoo$VERSION -U postgres -dRS && printf '123456\n123456\n' && exit
  sudo -u postgres -H -- psql -d postgres -c "CREATE USER odoo$VERSION WITH PASSWORD '$PASS'"
	sudo -u postgres -H -- psql -d postgres -c "ALTER USER odoo$VERSION WITH SUPERUSER;"
  #create odoo user
  adduser --system --home=/opt/odoo$VERSION --group odoo$VERSION

}
configure_logs(){
  mkdir /var/log/odoo$VERSION
}
install_python_dependencies(){

  if [ $VERSION -eq 10 ];then
    #install python dependencies
    pip install -r /opt/odoo$VERSION/doc/requirements.txt
    pip install -r /opt/odoo$VERSION/requirements.txt
  elif [ $VERSION -eq 12 ];then
    #install python3 dependencies
    pip3 install -r /opt/odoo$VERSION/doc/requirements.txt
    pip3 install -r /opt/odoo$VERSION/requirements.txt
  fi

  #Install Less CSS via Node.js and npm
  curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
  apt install -y nodejs
  npm install -g less less-plugin-clean-css

  #Install Stable Wkhtmltopdf
  cd /tmp
  wget https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
  dpkg -i wkhtmltox-0.12.1_linux-trusty-amd64.deb
  cp /usr/local/bin/wkhtmltopdf /usr/bin
  cp /usr/local/bin/wkhtmltoimage /usr/bin
}
create_odoo_config(){
  echo "[options]" >> /etc/odoo$VERSION-server.conf
  echo "admin_passwd = $PASS" >> /etc/odoo$VERSION-server.conf
  echo "db_host = False" >> /etc/odoo$VERSION-server.conf
  echo "db_port = False" >> /etc/odoo$VERSION-server.conf
  echo "db_user = odoo$VERSION" >> /etc/odoo$VERSION-server.conf
  echo "db_password = False" >> /etc/odoo$VERSION-server.conf
  echo "addons_path = /opt/odoo$VERSION/addons" >> /etc/odoo$VERSION-server.conf
  echo "xmlrpc_interface = 127.0.0.1" >> /etc/odoo$VERSION-server.conf
  echo "netrpc_interface = 127.0.0.1" >> /etc/odoo$VERSION-server.conf
  echo ";xmlrpc_port = $PORT" >> /etc/odoo$VERSION-server.conf
}
create_odoo_service(){
  echo "[Unit]" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "Description=Odoo Open Source ERP and CRM" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "Requires=postgresql.service" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "After=network.target postgresql.service" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "[Service]" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "Type=simple" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "PermissionsStartOnly=true" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "SyslogIdentifier=odoo-server" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "User=odoo$VERSION" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "Group=odoo$VERSION" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "ExecStart=/opt/odoo$VERSION/odoo-bin --config=/etc/odoo$VERSION-server.conf --addons-path=/opt/odoo$VERSION/addons/" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "WorkingDirectory=/opt/odoo$VERSION/" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "StandardOutput=journal+console" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "[Install]" >> /lib/systemd/system/odoo$VERSION-server.service
  echo "WantedBy=multi-user.target" >> /lib/systemd/system/odoo$VERSION-server.service

}
odoo_configuration(){

  #Create Odoo configuration File
  create_odoo_config

  #Create an Odoo Service
  create_odoo_service

  #Change File Ownership and Permissions
  chmod 755 /lib/systemd/system/odoo$VERSION-server.service
  chown root: /lib/systemd/system/odoo$VERSION-server.service
  chown -R odoo$VERSION: /opt/odoo$VERSION/
  chown odoo$VERSION:root /var/log/odoo$VERSION
  chown odoo$VERSION: /etc/odoo$VERSION-server.conf
  chmod 640 /etc/odoo$VERSION-server.conf

}
server_configuration(){
  check_apache2

  apt-get install nginx -y
  systemctl enable nginx

  cat > /etc/nginx/sites-available/$HOST << HERE
  upstream odoo {
  server 127.0.0.1:$PORT;
  }

  server {
  listen 80;
  server_name $HOST;

  access_log /var/log/nginx/$HOST.access.log;
  error_log /var/log/nginx/$HOST.error.log;

  proxy_buffers 16 64k;
  proxy_buffer_size 128k;

  location / {
  proxy_pass http://odoo;
  proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
  proxy_redirect off;

  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto https;
  }

  location ~* /web/static/ {
  proxy_cache_valid 200 60m;
  proxy_buffering on;
  expires 864000;
  proxy_pass http://odoo;
  }
  }
HERE

ln -s /etc/nginx/sites-available/$HOST /etc/nginx/sites-enabled/$HOST
rm /etc/nginx/sites-enabled/default
systemctl restart nginx


}
create_ssl_cert(){
  echo -n "\n" | add-apt-repository ppa:certbot/certbot
  apt-get update
  apt-get install python-certbot-nginx -y
  yes N | certbot --nginx -d $HOST -d www.$HOST -m $EMAIL --agree-tos
  openssl dhparam -out /etc/nginx/dhparams.pem 4096
  chmod 600 /etc/nginx/dhparams.pem
  service nginx restart
}
configur_ssl_server(){
  rm /etc/nginx/sites-available/$HOST
  cat > /etc/nginx/sites-available/$HOST << HERE
# Odoo servers
upstream odoo {
 server 127.0.0.1:8069;
}
# HTTP -> HTTPS
server {
    listen 80;
    server_name www.$HOST $HOST;
}
server {
   listen 443 ssl http2;
   server_name $HOST;

   ssl_certificate /etc/letsencrypt/live/$HOST/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/$HOST/privkey.pem;
   ssl_session_cache   shared:SSL:10m;
   ssl_session_timeout 10m;
   ssl_session_tickets off;

   ssl_dhparam /etc/nginx/dhparams.pem;

   ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
   ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
   ssl_prefer_server_ciphers on;

   add_header Strict-Transport-Security max-age=15768000;

   ssl_stapling on;
   ssl_stapling_verify on;
   ssl_trusted_certificate /etc/letsencrypt/live/$HOST/chain.pem;
   resolver 8.8.8.8 8.8.4.4;

   access_log /var/log/nginx/odoo$VERSION.access.log;
   error_log /var/log/nginx/odoo$VERSION.error.log;

   proxy_read_timeout 720s;
   proxy_connect_timeout 720s;
   proxy_send_timeout 720s;
   proxy_set_header X-Forwarded-Host \$host;
   proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
   proxy_set_header X-Forwarded-Proto \$scheme;
   proxy_set_header X-Real-IP \$remote_addr;

   location / {
     proxy_redirect off;
     proxy_pass http://odoo;
   }


   location ~* /web/static/ {
       proxy_cache_valid 200 90m;
       proxy_buffering    on;
       expires 864000;
       proxy_pass http://odoo;
  }

  # gzip
  gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
  gzip on;
}
HERE
service nginx restart
}
install_odoo(){
  upgrade_system
  configure_ufw
  install_dependencies
  create_user
  configure_logs
  git clone https://www.github.com/odoo/odoo --depth 1 --branch $VERSION.0 --single-branch /opt/odoo$VERSION
  install_python_dependencies

  odoo_configuration

  get_ip
  if [ "$HOST" != "$EXTERNAL_IP" ]; then
    server_configuration
  fi

  if [ "$HOST" != "$EXTERNAL_IP" ] && [ ! -z $EMAIL ];then
    create_ssl_cert
    configur_ssl_server
  fi

  test_the_server
  print_url
}
test_the_server(){
  systemctl start odoo$VERSION-server
  systemctl enable odoo$VERSION-server
  systemctl status odoo$VERSION-server
}
print_url(){
  if [ -z $EMAIL ];then
    HOST=http://$HOST
  else
    HOST=https://$HOST
  fi
  cat 1>&2 <<HERE
         ******************************************************************
         *           Installation completed successfully
         *           URL: $HOST
         *
         ******************************************************************
HERE
}

main "$@" || exit 1
