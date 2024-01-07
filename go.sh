#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

NEW_USER="angelica"
NEW_USER_PASSWORD=$(openssl rand -base64 32|sha256sum|base64|head -c 32| tr '[:upper:]' '[:lower:]')
WWW_DIR="/var/www"
SITE_DIR="angelica"

sudo apt update
sudo apt upgrade -y

sudo apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-ctype php8.1-curl php8.1-dom php8.1-fileinfo php8.1-filter php8.1-hash php8.1-mbstring php8.1-openssl php8.1-pcre php8.1-pdo php8.1-session php8.1-tokenizer php8.1-xml
sudo apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-ctype php8.2-curl php8.2-dom php8.2-fileinfo php8.2-filter php8.2-hash php8.2-mbstring php8.2-openssl php8.2-pcre php8.2-pdo php8.2-session php8.2-tokenizer php8.2-xml
sudo apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-ctype php8.3-curl php8.3-dom php8.3-fileinfo php8.3-filter php8.3-hash php8.3-mbstring php8.3-openssl php8.3-pcre php8.3-pdo php8.3-session php8.3-tokenizer php8.3-xml

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
if test -f "$NGINX"; then
    sudo unlink NGINX
fi
sudo touch $NGINX
sudo cat > "$NGINX" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root "$WWW_DIR/$SITE_DIR/public";
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
    location ~ /\.ht {
        deny all;
    }
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
