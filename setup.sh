#!/bin/bash
set -e

echo "--- 1. Mise à jour de Debian et installation des dépendances ---"
apt update && apt upgrade -y
apt install git curl unzip p7zip-full sudo tmux net-tools php php-mysqli ufw -y

echo "--- 2. Configuration de SSH ---"
sed -ie '0,/#PermitRootLogin prohibit-password/s/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
service sshd restart


echo "--- 3. Configuration du firewall UFW ---"

# Bloque par défaut toutes les connexions entrantes.
ufw default deny incoming

# Autorise toutes les connexions sortantes du serveur.
ufw default allow outgoing

# SSH - nécessaire pour PuTTY / WinSCP.
ufw allow 22/tcp comment 'SSH'

# AzerothCore Authserver - connexion au serveur WoW.
ufw allow 3724/tcp comment 'WoW Auth'

# AzerothCore Worldserver - connexion au monde.
ufw allow 8085/tcp comment 'WoW World'

echo ""
echo "Ports autorisés par UFW :"
echo "  22/tcp   -> SSH / PuTTY / WinSCP"
echo "  3724/tcp -> AzerothCore Authserver"
echo "  8085/tcp -> AzerothCore Worldserver"
echo ""

echo "Activation du firewall UFW..."
ufw --force enable

echo ""
echo "Attente de la prise en compte du firewall..."
sleep 2

echo ""
echo "Statut du firewall :"
ufw status verbose

echo ""
echo "UFW est activé et configuré."
echo ""


echo "--- 4. Configuration de GRUB ---"
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=1/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
update-grub

echo "--- 5. Configuration de l'IP Statique ---"
INTERFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
CURRENT_IP=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet )\d+(\.\d+){3}')
GATEWAY=$(ip route | grep default | awk '{print $3}')

echo "Application de l'IP statique : $CURRENT_IP sur l'interface $INTERFACE (Passerelle : $GATEWAY)"

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
    dns-nameservers $GATEWAY
EOF

systemctl restart networking.service

echo "--- 6. Clonage AzerothCore et module principal ---"
cd ~
git clone https://github.com/mod-playerbots/azerothcore-wotlk.git --branch=Playerbot

cd ~/azerothcore-wotlk/modules
git clone https://github.com/mod-playerbots/mod-playerbots.git --branch=master

echo "--- 7. Ajout des sous-modules personnalisés ---"
cd ~/azerothcore-wotlk
git submodule add -f https://github.com/ZhengPeiRu21/mod-individual-progression modules/mod-individual-progression
git submodule add -f https://github.com/azerothcore/mod-ah-bot modules/mod-ah-bot
git submodule add -f https://github.com/jrad7/mod-dungeon-clear modules/mod-dungeon-clear
git submodule add -f https://github.com/Wishmaster117/mod-multibot-bridge modules/mod-multibot-bridge
git submodule add -f https://github.com/azerothcore/mod-account-mounts modules/mod-account-mounts
git submodule add -f https://github.com/azerothcore/eluna-ts modules/eluna-ts

echo "--- 8. Téléchargement du script finalize.sh ---"
curl -fL https://raw.githubusercontent.com/syltia/wow/main/finalize.sh -o /root/finalize.sh
chmod +x /root/finalize.sh

echo "--- 9. Création du script de démarrage et des alias ---"
cat << 'EOF' > /root/start.sh
#!/bin/bash

cd ~/azerothcore-wotlk/env/dist/bin || exit 1

authserver="./authserver"
worldserver="./worldserver"

authserver_session="auth-session"
worldserver_session="world-session"

# =========================
# AUTHSERVER
# =========================

if tmux has-session -t "$authserver_session" 2>/dev/null; then
    echo "Authserver session already exists: $authserver_session"
else
    tmux new-session -d -s "$authserver_session"
    tmux send-keys -t "$authserver_session" "$authserver" C-m
    echo "Created authserver session: $authserver_session"
fi

# =========================
# WORLDSERVER
# =========================

start_worldserver()
{
    tmux send-keys -t "$worldserver_session" \
'while true; do
    ./worldserver
    exit_code=$?

    if [ "$exit_code" -eq 2 ]; then
        echo
        echo "Worldserver requested restart. Restarting..."
        echo
        sleep 2
    else
        echo
        echo "Worldserver stopped with exit code $exit_code."
        echo "Worldserver will remain stopped."
        echo
        break
    fi
done' C-m
}

if tmux has-session -t "$worldserver_session" 2>/dev/null; then

    current_command=$(tmux display-message -p -t "$worldserver_session" '#{pane_current_command}')

    if [ "$current_command" = "worldserver" ] || [ "$current_command" = "./worldserver" ]; then
        echo "Worldserver is already running: $worldserver_session"
    else
        echo "Worldserver session exists but server is stopped."
        echo "Starting worldserver..."
        start_worldserver
    fi

else
    tmux new-session -d -s "$worldserver_session"
    echo "Created worldserver session: $worldserver_session"

    start_worldserver
fi

echo
echo "Worldserver console : tmux attach -t $worldserver_session"
echo "Authserver console  : tmux attach -t $authserver_session"
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

echo "--- 10. Lancement du script des dépendances d'AzerothCore ---"
cd ~/azerothcore-wotlk
./acore.sh install-deps

echo "=================================================================="
echo "Script de préparation terminé ! Votre machine est prête."
echo "=================================================================="
echo ""

read -p "Voulez-vous lancer la compilation maintenant ? (o/n) : " choice
if [[ "$choice" =~ ^[oO](ui)?$|[yY](es)?$ ]]; then
    echo "Lancement de la compilation..."
    cd ~/azerothcore-wotlk
    ./acore.sh compiler all
else
    echo "Compilation ignorée. Vous pourrez la lancer plus tard avec l'alias : compile"
fi
