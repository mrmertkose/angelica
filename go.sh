#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

NEW_USER="angelica"
NEW_USER_PASSWORD=$(openssl rand -base64 32|sha256sum|base64|head -c 32| tr '[:upper:]' '[:lower:]')
WWW_DIR="/var/www"
SITE_DIR="angelica"

sudo apt update
sudo apt upgrade -y

sudo apt install -y curl wget zip unzip
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt update

sudo apt install -y php8.1
sudo apt install -y php8.2

sudo apt install -y php8.1-fpm php8.1-common php8.1-mysql php8.1-xml php8.1-xmlrpc php8.1-curl php8.1-gd php8.1-imagick php8.1-cli php8.1-dev php8.1-imap php8.1-mbstring php8.1-opcache php8.1-soap php8.1-zip php8.1-redis php8.1-intl
sudo apt install -y php8.2-fpm php8.2-common php8.2-mysql php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick php8.2-cli php8.2-dev php8.2-imap php8.2-mbstring php8.2-opcache php8.2-soap php8.2-zip php8.2-redis php8.2-intl

sudo update-alternatives --set php /usr/bin/php8.1

sudo apt install -y nodejs npm
sudo apt install -y composer
sudo apt install -y git
sudo apt install -y nginx
sudo apt install -y ffmpeg

# CREATE USER
sudo useradd -m -s /bin/bash $NEW_USER
echo "$NEW_USER:$NEW_USER_PASSWORD" | sudo chpasswd

# USER ADD SUDO
sudo usermod -aG sudo $NEW_USER

## FRANKENPHP
#sudo curl -L -o "$LOCAL_BIN_DIR/frankenphp" https://github.com/dunglas/frankenphp/releases/latest/download/frankenphp-linux-x86_64
#sudo chmod +x "$LOCAL_BIN_DIR/frankenphp"
#
## CADDYFILE
#CADDYFILE="$LOCAL_BIN_DIR/Caddyfile"
#sudo cat > "$CADDYFILE" <<EOF
#{
#        frankenphp
#        order php_server before file_server
#}
#localhost {
#        root * "$WWW_DIR/$SITE_DIR/public"
#        encode zstd gzip
#        php_server {
#                resolve_root_symlink
#        }
#}
#EOF
#sudo chmod +x $CADDYFILE
#
##COMPOSER INSTALL
#curl -sS https://getcomposer.org/installer -o composer-setup.php
#sudo frankenphp php-cli composer-setup.php --install-dir="$LOCAL_BIN_DIR" --filename=composer

NGINX=/etc/nginx/sites-available/default
sudo touch $NGINX
sudo cat > "$NGINX" <<EOF
server {
    listen 80;
    server_name localhost;
    root /var/www/$SITE_DIR/public;

    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    error_log  /var/log/nginx/default_error.log;
    access_log /var/log/nginx/default_access.log;
}
EOF

sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled
sudo service nginx restart

# FIREWALL
sudo apt-get -y install fail2ban
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


# MAIN PROJECT FILE
sudo mkdir -p "$WWW_DIR/$SITE_DIR"
sudo git clone https://github.com/mrmertkose/angelica.git "$WWW_DIR/$SITE_DIR"
sudo chown -R www-data:$NEW_USER "$WWW_DIR/$SITE_DIR"
sudo chmod -R 750 "$WWW_DIR/$SITE_DIR"

cd "$WWW_DIR/$SITE_DIR" && composer update --no-interaction
cd "$WWW_DIR/$SITE_DIR" && sudo cp .env.example .env
cd "$WWW_DIR/$SITE_DIR" && php artisan key:generate

#CRON CONFIG
TASK=/etc/cron.d/$NEW_USER.crontab
touch $TASK
cat > "$TASK" <<EOF
* * * * * cd "$WWW_DIR/$SITE_DIR" && php artisan schedule:run >> /dev/null 2>&1
EOF
crontab $TASK

sleep 1s

#START SERVER
#sudo systemctl start frankServer
#sudo systemctl enable frankServer
#sudo systemctl daemon-reload
