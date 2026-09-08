# ==========================================
# COMPLETE MYSQL & CONFIG AUTOMATION
# ==========================================

echo "==> Updating MySQL configuration file completely (/etc/mysql/my.cnf)..."
sudo bash -c 'cat > /etc/mysql/my.cnf' << 'EOF'
# Copyright (c) 2015, 2026, Oracle and/or its affiliates.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2.0,
# as published by the Free Software Foundation.
#
# This program is designed to work with certain software (including
# but not limited to OpenSSL) that is licensed under separate terms,
# as designated in a particular file or component or in included license
# documentation.  The authors of MySQL hereby grant you an additional
# permission to link the program and your derivative works with the
# separately licensed software that they have either included with
# the program or referenced in the documentation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License, version 2.0, for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA

#
# The MySQL  Server configuration file.
#
# For explanations see
# http://dev.mysql.com/doc/mysql/en/server-system-variables.html

# * IMPORTANT: Additional settings that can override those from this file!
#    The files must end with '.cnf', otherwise they'll be ignored.
#
!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mysql.conf.d/
bind-address            = 0.0.0.0
mysqlx-bind-address     = 0.0.0.0
disable_log_bin
EOF

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
    start
else
    echo "==> Launch canceled. You can type 'start' later when you are ready."
fi