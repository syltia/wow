# ==========================================
# COMPLETE MYSQL & CONFIG AUTOMATION
# ==========================================

echo "==> Creating custom MySQL configuration for AzerothCore..."
sudo bash -c 'cat << 'EOF' > /etc/mysql/conf.d/azerothcore.cnf
[mysqld]
bind-address         = 0.0.0.0
mysqlx-bind-address  = 0.0.0.0
disable_log_bin
EOF'

echo "==> Restarting MySQL and waiting for the service..."
sudo systemctl restart mysql

# Safety loop to ensure MySQL is fully operational
until sudo mysqladmin ping &>/dev/null; do
    echo "Waiting for MySQL to start..."
    sleep 2
done
echo "==> MySQL is online!"

echo "==> Creating MySQL user and databases..."
sudo mysql -u root << 'EOF'
DROP USER IF EXISTS 'acore'@'localhost';
CREATE USER 'acore'@'localhost' IDENTIFIED BY 'acore' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0;
GRANT ALL PRIVILEGES ON * . * TO 'acore'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `acore_playerbots` . * TO 'acore'@'localhost' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS `acore_world` DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `acore_characters` DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `acore_auth` DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `acore_world` . * TO 'acore'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `acore_characters` . * TO 'acore'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `acore_auth` . * TO 'acore'@'localhost' WITH GRANT OPTION;
EOF

echo "==> Fetching client data and initializing configuration files..."
cd ~/azerothcore-wotlk
./acore.sh client-data
cp env/dist/etc/authserver.conf.dist env/dist/etc/authserver.conf
cp env/dist/etc/worldserver.conf.dist env/dist/etc/worldserver.conf
cp ~/azerothcore-wotlk/env/dist/etc/modules/playerbots.conf.dist ~/azerothcore-wotlk/env/dist/etc/modules/playerbots.conf

echo "==> Installation and setup completed successfully!"

# Interactive prompt to launch the server
read -p "Do you want to launch the server for the first time now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "==> Launching server..."
    bash /root/start.sh
else
    echo "==> Launch canceled. You can type 'start' later when you are ready."
fi
