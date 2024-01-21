#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

NEW_USER="angelica"
NEW_USER_PASSWORD=$(openssl rand -base64 32|sha256sum|base64|head -c 32| tr '[:upper:]' '[:lower:]')
DBPASS=$(openssl rand -base64 24|sha256sum|base64|head -c 32| tr '[:upper:]' '[:lower:]')
WWW_DIR="/var/www"
SITE_DIR="angelica"

sudo NEEDRESTART_MODE=l apt update -y
sudo NEEDRESTART_MODE=l apt upgrade -y

sudo NEEDRESTART_MODE=l apt install -y curl wget zip unzip nginx rpl

sudo NEEDRESTART_MODE=l apt install -y software-properties-common
sudo NEEDRESTART_MODE=l add-apt-repository -y ppa:ondrej/php

sudo NEEDRESTART_MODE=l apt update -y

sudo NEEDRESTART_MODE=l apt install -y php8.1 php8.1-fpm php8.1-common php8.1-mysql php8.1-xml php8.1-xmlrpc php8.1-curl php8.1-gd php8.1-imagick php8.1-cli php8.1-dev php8.1-imap php8.1-mbstring php8.1-opcache php8.1-soap php8.1-zip php8.1-redis php8.1-intl
sudo NEEDRESTART_MODE=l apt install -y php8.2 php8.2-fpm php8.2-common php8.2-mysql php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick php8.2-cli php8.2-dev php8.2-imap php8.2-mbstring php8.2-opcache php8.2-soap php8.2-zip php8.2-redis php8.2-intl

sudo update-alternatives --set php /usr/bin/php8.1

sudo NEEDRESTART_MODE=l apt install -y composer git ffmpeg supervisor

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo NEEDRESTART_MODE=l apt-get install -y nodejs

# CREATE USER
sudo useradd -m -s /bin/bash $NEW_USER
echo "$NEW_USER:$NEW_USER_PASSWORD" | sudo chpasswd

# USER ADD SUDO
sudo usermod -aG sudo $NEW_USER

IP=""
if [ -n "$1" ]; then
  IP=localhost
else
  IP=$(curl -s https://checkip.amazonaws.com)
fi

NGINX=/etc/nginx/sites-available/default
if test -f "$NGINX"; then
    sudo unlink NGINX
fi
sudo touch $NGINX
sudo cat > "$NGINX" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name "$IP";
    root /var/www/angelica/public;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    client_body_timeout 10s;
    client_header_timeout 10s;
    client_max_body_size 256M;
    index index.html index.php;
    charset utf-8;
    server_tokens off;
    location / {
        try_files   \$uri     \$uri/  /index.php?\$query_string;
    }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    error_page 404 /index.php;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
sudo service nginx restart

# FIREWALL
sudo NEEDRESTART_MODE=l apt-get -y install fail2ban
JAIL=/etc/fail2ban/jail.local
sudo cat > "$JAIL" <<EOF
[DEFAULT]
bantime = 3600
banaction = iptables-multiport
[sshd]
enabled = true
logpath  = /var/log/auth.log
EOF
sudo systemctl restart fail2ban
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow "Nginx FULL"

# MYSQL
sudo NEEDRESTART_MODE=l apt-get install -y mysql-server
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Press y|Y for Yes, any other key for No:\"
send \"n\r\"
expect \"New password:\"
send \"$DBPASS\r\"
expect \"Re-enter new password:\"
send \"$DBPASS\r\"
expect \"Remove anonymous users? (Press y|Y for Yes, any other key for No)\"
send \"y\r\"
expect \"Disallow root login remotely? (Press y|Y for Yes, any other key for No)\"
send \"n\r\"
expect \"Remove test database and access to it? (Press y|Y for Yes, any other key for No)\"
send \"y\r\"
expect \"Reload privilege tables now? (Press y|Y for Yes, any other key for No) \"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"
/usr/bin/mysql -u root -p$DBPASS <<EOF
use mysql;
CREATE USER 'angelica'@'%' IDENTIFIED WITH mysql_native_password BY '$DBPASS';
GRANT ALL PRIVILEGES ON *.* TO 'angelica'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF


# MAIN PROJECT FILE
/usr/bin/mysql -u root -p$DBPASS <<EOF
CREATE DATABASE IF NOT EXISTS angelica;
EOF
sudo mkdir -p "$WWW_DIR/$SITE_DIR"
sudo git clone https://github.com/mrmertkose/angelica.git "$WWW_DIR/$SITE_DIR"
sudo chown -R $NEW_USER:www-data "$WWW_DIR/$SITE_DIR"
sudo chmod -R 750 "$WWW_DIR/$SITE_DIR"
cd "$WWW_DIR/$SITE_DIR" && composer update --no-interaction
cd "$WWW_DIR/$SITE_DIR" && sudo cp .env.example .env
cd "$WWW_DIR/$SITE_DIR" && npm install
cd "$WWW_DIR/$SITE_DIR" && npm run build
sudo rpl -i -w "DB_USERNAME=user" "DB_USERNAME=angelica" /var/www/angelica/.env
sudo rpl -i -w "DB_PASSWORD=pass" "DB_PASSWORD=$DBPASS" /var/www/angelica/.env
sudo rpl -i -w "DB_DATABASE=db" "DB_DATABASE=angelica" /var/www/angelica/.env
sudo rpl -i -w "APP_ENV=local" "APP_ENV=production" /var/www/angelica/.env
sudo rpl -i -w "APP_DEBUG=true" "APP_DEBUG=false" /var/www/angelica/.env
sudo rpl -i -w "APP_URL=http://localhost" "APP_URL=http://$IP" /var/www/angelica/.env
sudo rpl -i -w "CHANGE_IP" $IP /var/www/angelica/database/seeders/DatabaseSeeder.php
sudo rpl -i -w "CHANGE_SSH_PASSWORD" $NEW_USER_PASSWORD /var/www/angelica/database/seeders/DatabaseSeeder.php
sudo rpl -i -w "CHANGE_DB_PASSWORD" $DBPASS /var/www/angelica/database/seeders/DatabaseSeeder.php
cd "$WWW_DIR/$SITE_DIR" && php artisan migrate --seed --force
cd "$WWW_DIR/$SITE_DIR" && php artisan optimize:clear
cd "$WWW_DIR/$SITE_DIR" && php artisan storage:link
cd "$WWW_DIR/$SITE_DIR" && php artisan key:generate
cd "$WWW_DIR/$SITE_DIR" && php artisan optimize
sudo chmod -R o+w "$WWW_DIR/$SITE_DIR/storage"
sudo chmod -R 775 "$WWW_DIR/$SITE_DIR/storage"
sudo chmod -R o+w "$WWW_DIR/$SITE_DIR/bootstrap/cache"
sudo chmod -R 775 "$WWW_DIR/$SITE_DIR/bootstrap/cache"


# LET'S ENCRYPT
sudo NEEDRESTART_MODE=l apt-get install -y certbot
sudo NEEDRESTART_MODE=l apt-get install -y python3-certbot-nginx

#CRON CONFIG
TASK=/etc/cron.d/$NEW_USER.crontab
touch $TASK
cat > "$TASK" <<EOF
10 4 * * 7 certbot renew --nginx --non-interactive --post-hook "systemctl restart nginx"
* * * * * cd "$WWW_DIR/$SITE_DIR" && php artisan schedule:run >> /dev/null 2>&1
20 4 * * 7 apt-get -y update
40 4 * * 7 DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical sudo apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade
20 5 * * 7 apt-get clean && apt-get autoclean
EOF
crontab $TASK

TASK=/etc/supervisor/conf.d/angelica.conf
touch $TASK
cat > "$TASK" <<EOF
[program:angelica-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/angelica/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=angelica
numprocs=8
redirect_stderr=true
stdout_logfile=/var/www/angelica/storage/logs/angelica_worker.log
stopwaitsecs=3600
EOF
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
sudo service supervisor restart

sudo service nginx restart


# SETUP COMPLETE MESSAGE
echo "***********************************************************"
echo "                    SETUP COMPLETE"
echo "***********************************************************"
echo ""
echo " SSH root user: angelica"
echo " SSH root pass: $NEW_USER_PASSWORD"
echo " MySQL root user: angelica"
echo " MySQL root pass: $DBPASS"
echo ""
echo " To manage your server visit: http://$IP"
echo " and click on 'dashboard' button."
echo " Default credentials are: demouser@mail.com / 123456789"
echo ""
echo "***********************************************************"
echo "          DO NOT LOSE AND KEEP SAFE THIS DATA"
echo "***********************************************************"
