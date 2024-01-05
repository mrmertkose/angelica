#!/bin/bash

NEW_USER="angelica"
NEW_USER_PASSWORD="123456"
WWW_DIR="/var/www"
SITE_DIR="captain"
FRANKEN_DIR="/etc/franken"

sudo apt-get update
sudo apt-get -y install software-properties-common curl wget zip unzip git

# CREATE USER
sudo useradd -m -s /bin/bash $NEW_USER
echo "$NEW_USER:$NEW_USER_PASSWORD" | sudo chpasswd

# USER ADD SUDO
sudo usermod -aG sudo $NEW_USER

# FRANKENPHP
sudo mkdir -p $FRANKEN_DIR
sudo curl -L -o "$FRANKEN_DIR/frankenphp" https://github.com/dunglas/frankenphp/releases/latest/download/frankenphp-linux-x86_64
sudo chmod +x "$FRANKEN_DIR/frankenphp"
sudo chown -R www-data:$NEW_USER "$FRANKEN_DIR/frankenphp"

# CADDYFILE
CADDYFILE="$FRANKEN_DIR/Caddyfile"
sudo cat > "$CADDYFILE" <<EOF
{
        frankenphp
        order php_server before file_server
}
localhost {
        root * "$WWW_DIR/$SITE_DIR/public"
        encode zstd gzip
        php_server {
                resolve_root_symlink
        }
}
EOF
sudo chmod +x $CADDYFILE
sudo chown -R www-data:$NEW_USER $CADDYFILE


# SERVER START CONFIG
sudo touch /etc/systemd/system/frankServer.service
sudo cat << EOF > /etc/systemd/system/frankServer.service
[Unit]
Description=FrankenphpServer Service
After=network.target

[Service]
Restart=always
ExecStart="$FRANKEN_DIR/frankenphp" run --config $CADDYFILE

[Install]
WantedBy=multi-user.target
EOF

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

# MAIN PROJECT FILE --> (*)
sudo mkdir -p "$WWW_DIR/$SITE_DIR"
sudo git clone https://github.com/mrmertkose/angelica.git "$WWW_DIR/$SITE_DIR"
sudo chown -R www-data:$NEW_USER "$WWW_DIR/$SITE_DIR"
sudo chmod -R 750 "$WWW_DIR/$SITE_DIR"

#CRON CONFIG
TASK=/etc/cron.d/$NEW_USER.crontab
touch $TASK
cat > "$TASK" <<EOF
* * * * * cd "$WWW_DIR/$SITE_DIR" && "$FRANKEN_DIR/frankenphp" php-cli artisan schedule:run >> /dev/null 2>&1
EOF
crontab $TASK

sleep 1s

#START SERVER
sudo systemctl start frankServer
sudo systemctl enable frankServer
sudo systemctl daemon-reload