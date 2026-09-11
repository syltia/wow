#!/bin/bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

echo "--- 1. Updating Debian ---"
apt update
apt upgrade -y

echo "--- 2. Installing base development tools ---"
apt install -y \
    build-essential \
    cmake \
    ninja-build \
    clang \
    lldb \
    gdb \
    git \
    curl \
    wget \
    tmux \
    pkg-config \
    ca-certificates \
    gnupg \
    unzip \
    zip \
    libssl-dev \
    zlib1g-dev

if ! command -v ufw >/dev/null 2>&1; then
    echo "--- Installing UFW ---"
    apt install -y ufw
else
    echo "--- UFW is already installed ---"
fi

echo "--- Configuring UFW ---"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 3724/tcp comment 'WoW Auth'
ufw allow 8085/tcp comment 'WoW World'
ufw --force enable
ufw status verbose

echo "--- 3. Configuring SSH ---"
sed -ie '0,/#PermitRootLogin prohibit-password/s/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
service sshd restart

echo "--- 4. Configuring GRUB ---"
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=1/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
update-grub

echo "--- 5. Configuring Static IP ---"
INTERFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
CURRENT_IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet )\d+(\.\d+){3}' | head -n1)
GATEWAY=$(ip route | awk '/default/ {print $3; exit}')

echo "Applying static IP: $CURRENT_IP on interface $INTERFACE (Gateway: $GATEWAY)"

cat <<EOF > /etc/network/interfaces
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet static
    address $CURRENT_IP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-domain azeroth.core
    dns-nameservers 8.8.8.8
EOF

systemctl restart networking.service
until ping -c 1 github.com &>/dev/null; do
    sleep 1
done

echo "--- 6. Cloning AzerothCore and main module ---"
cd ~
git clone https://github.com/mod-playerbots/azerothcore-wotlk.git --branch=Playerbot

cd ~/azerothcore-wotlk/modules
if [ ! -d "mod-playerbots" ]; then
    git clone https://github.com/mod-playerbots/mod-playerbots.git --branch=master
fi

echo "--- 7. Adding custom submodules ---"
cd ~/azerothcore-wotlk
git submodule add -f https://github.com/ZhengPeiRu21/mod-individual-progression modules/mod-individual-progression
git submodule add -f https://github.com/azerothcore/mod-ah-bot modules/mod-ah-bot
git submodule add -f https://github.com/jrad7/mod-dungeon-clear modules/mod-dungeon-clear
git submodule add -f https://github.com/Wishmaster117/mod-multibot-bridge modules/mod-multibot-bridge
git submodule add -f https://github.com/azerothcore/mod-account-mounts modules/mod-account-mounts

echo "--- 8. Downloading finalize script ---"
curl -o /root/finalize.sh https://raw.githubusercontent.com/syltia/wow/main/finalize.sh && chmod +x /root/finalize.sh

echo "--- 9. Creating startup script and aliases ---"
cat << 'EOF' > /root/start.sh
cd ~/azerothcore-wotlk/env/dist/bin
authserver="./authserver"
worldserver="./worldserver"

authserver_session="auth-session"
worldserver_session="world-session"

if tmux new-session -d -s $authserver_session; then
    echo "Created authserver session: $authserver_session"
else
    echo "Error when trying to create authserver session: $authserver_session"
fi

if tmux new-session -d -s $worldserver_session; then
    echo "Created worldserver session: $worldserver_session"
else
    echo "Error when trying to create worldserver session: $worldserver_session"
fi

if tmux send-keys -t $authserver_session "$authserver" C-m; then
    echo "Executed \"$authserver\" inside $authserver_session"
    echo "You can attach to $authserver_session and check the result using \"tmux attach -t $authserver_session\""
else
    echo "Error when executing \"$authserver\" inside $authserver_session"
fi

if tmux send-keys -t $worldserver_session "$worldserver" C-m; then
    echo "Executed \"$worldserver\" inside $worldserver_session"
    echo "You can attach to $worldserver_session and check the result using \"tmux attach -t $worldserver_session\""
else
    echo "Error when executing \"$worldserver\" inside $worldserver_session"
fi
EOF

chmod +x /root/start.sh

cat << 'EOF' > ~/.bashrc
# ~/.bashrc: executed by bash(1) for non-login shells.

# Note: PS1 is set in /etc/profile, and the default umask is defined
# in /etc/login.defs. You should not need this unless you want different
# defaults for root.
# PS1='${debian_chroot:+($debian_chroot)}\h:\w\$ '
# umask 022

# You may uncomment the following lines if you want `ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "$(dircolors)"
# alias ls='ls $LS_OPTIONS'
# alias ll='ls $LS_OPTIONS -l'
# alias l='ls $LS_OPTIONS -lA'
#
# Some more alias to avoid making mistakes:
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'
alias wow='cd ~/azerothcore-wotlk;tmux attach -t world-session'
alias auth='cd ~/azerothcore-wotlk;tmux attach -t auth-session'
alias start='bash /root/start.sh'
alias stop='tmux kill-server'
alias compile='cd ~/azerothcore-wotlk;./acore.sh compiler all'
alias build='cd ~/azerothcore-wotlk;./acore.sh compiler build'
alias update='cd ~/azerothcore-wotlk;git pull;cd ~/azerothcore-wotlk/modules/mod-playerbots;git pull'
alias pb='nano ~/azerothcore-wotlk/env/dist/etc/modules/playerbots.conf'
alias world='nano ~/azerothcore-wotlk/env/dist/etc/worldserver.conf'
alias updatemods="cd ~/azerothcore-wotlk/modules;find . -mindepth 1 -maxdepth 1 -type d -print -exec git -C {} pull \;"
alias ah='nano ~/azerothcore-wotlk/env/dist/etc/modules/mod_ahbot.conf'
alias qqq='sudo shutdown now'
EOF

source ~/.bashrc

echo "--- 10. Running AzerothCore dependencies script ---"
cd ~/azerothcore-wotlk
./acore.sh install-deps

echo "=================================================================="
echo "Preparation script completed! Your machine is ready."
echo "=================================================================="
echo ""

read -p "Do you want to run compilation now? (y/n) : " choice
if [[ "$choice" =~ ^[oO](ui)?$|[yY](es)?$ ]]; then
    echo "Starting compilation..."
    cd ~/azerothcore-wotlk
    ./acore.sh compiler all
else
    echo "Compilation skipped. You can run it later using the alias: compile"
fi
