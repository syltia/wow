

 ## Prerequisites
    You must be connected as root.
```bash
 apt install git curl unzip p7zip-full sudo tmux net-tools php php-mysqli -y
 ```
i made a personnal script for install azerothcore and compile when finish. This custom script automates the complete setup and deployment of an [**AzerothCore**](https://github.com/azerothcore/azerothcore-wotlk) server with custom modules that I use on a fresh Debian VM (debian-13.6.0 by 09/08/26).
### Features & Automation
* **System & Dependencies**: Updates Debian and installs all required packages.
* **SSH & GRUB Optimization**: 
  * Configures SSH to allow root access if needed.
  * Tweaks **GRUB** settings (`GRUB_DEFAULT=1` and `GRUB_TIMEOUT=0`) to speed up system boot times by skipping the boot menu.
* **Network Configuration**: Automatically detects your network interface, reads the current configuration, and sets up a **static IP address** and DNS settings to ensure stable connectivity.
* **Core & Modules Management**: 
  * Clones the main AzerothCore repository (Playerbot branch).
  * Automatically adds and integrates the custom modules that I use: 
    * [`mod-individual-progression`](https://github.com/azerothcore/mod-individual-progression)
    * [`mod-ah-bot`](https://github.com/azerothcore/mod-ah-bot)
    * [`mod-dungeon-clear`](https://github.com/jrad7/mod-dungeon-clear)
    * [`mod-multibot-bridge`](https://github.com/Wishmaster117/mod-multibot-bridge)
    * [`mod-account-mounts`](https://github.com/azerothcore/mod-account-mounts)
* **Server Management & `tmux` Integration**: 
  * Generates a `/root/start.sh` script that automatically launches both the `authserver` and `worldserver` inside isolated `tmux` sessions (`auth-session` and `world-session`).
* **Custom Bash Aliases**: Configures useful shortcuts in `.bashrc` for daily management:
  * `wow`: Instantly attaches to the live `worldserver` `tmux` session.
  * `auth`: Instantly attaches to the `authserver` `tmux` session. *(And you can see the auth server any time it's running by typing `auth`. This isn't really necessary for most cases and you shouldn't need to go in here.)*
  * `start`: Quickly executes the `start.sh` script to boot up the server.
  * `stop`: Gracefully shuts down all running `tmux` server sessions (`tmux kill-server`).
  * `compile` / `build`: Shortcuts to compile or rebuild the server via `./acore.sh`.
  * `update`: Pulls the latest updates from the main repository and Playerbots.
  * `pb`, `world`, `ah`: Direct shortcuts to quickly edit configuration files (`playerbots.conf`, `worldserver.conf`, `mod_ahbot.conf`) using `nano`.
  * `qqq`: Instant server shutdown (debian) shortcut (`sudo shutdown now`).
   
* **Compilation & Manual Post-Setup Steps:**
  * The script automatically handles the dependency installation (`./acore.sh install-deps`), downloads the `finalize.sh` script into `/root`, and triggers the full compilation process (you **must** press **y** when prompted, otherwise the compilation will not start).
  * Once the automated script finishes compiling, run the finalization script:
    ```bash
    cd /root
    ./finalize.sh
    ```
  * **Important:** Once `finalize.sh` has completed its work, you must start the server using the `start` command before proceeding with the configuration steps.
  * Then follow the manual steps below to configure your databases and set up your accounts.

* **0. Download the Game Client (Recommended First)**
  * Download the WotLK 3.3.5a client (17GB) from ChromieCraft and extract it to your fastest drive: [ChromieCraft Downloads](https://www.chromiecraft.com/en/downloads/)
  * *(Doing this now lets it download while you handle the server setup below!)*

* **1. Configure Realm Name & IP Address**
  * Run these commands in your server terminal:
    ```bash
    sudo mysql -u root
    use acore_auth;
    UPDATE realmlist SET name = 'My Realm Name' WHERE id = 1;
    ```
  * For local LAN play, use your server's local IP (e.g., `192.168.1.250`).
  * For internet/multiplayer play so friends can join, get your external IP with `curl ipv4.icanhazip.com` and use that instead.
    ```bash
    UPDATE realmlist SET address = 'YOUR_SERVER_IP' WHERE id = 1;
    exit;
    ```

* **1.1 Router Port Forwarding (For Internet Play Only)**
  * If you want friends anywhere in the world to connect to your server, you must open and port-forward the following two ports in your router settings to your server's local IP address:
    * `3724 TCP` (AUTH)
    * `8085 TCP` (WORLD)
  * *(Not required if you are only playing on your local network / LAN)*

* **2. Create Your Admin / GM Account**
  * Start the server if not running, then create your account and grant GM status:
    ```bash
    start
    wow
    account create <your_username> <your_password>
    account set gmlevel <your_username> 3 -1
    ```

* **3. Set Up the Auction House Bot (AHBot)**
  * Copy the AHBot configuration file first:
    ```bash
    cp ~/azerothcore-wotlk/env/dist/etc/modules/mod_ahbot.conf.dist ~/azerothcore-wotlk/env/dist/etc/modules/mod_ahbot.conf
    ```
  * Create a dedicated account for the AHBot seller:
    ```bash
    account create ahbot password
    ```
  * *(Log into this account in-game, create your character to act as the seller, then log out).*
  * Retrieve your character's GUID:
    ```bash
    lookup player account ahbot
    ```
  * Open the AHBot config file:
    ```bash
    ah
    ```
  * **Inside the AHBot config file (`ah`)**:
    * Find and set: `AuctionHouseBot.EnableSeller = 1`
    * Find and set: `AuctionHouseBot.EnableBuyer = 1`
    * Set items per cycle: `AuctionHouseBot.ItemsPerCycle = 575`
    * Enter your character's GUID found earlier.
    * *(Save with `CTRL+S`, exit with `CTRL+X`)*

i follow this guide https://youtu.be/UG900F19GPk. Thank you, nirv!
