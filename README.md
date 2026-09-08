### Features & Automation

i made a personnal script for install azerothcore and compile when finish. This custom script automates the complete setup and deployment of an [**AzerothCore**](https://github.com/azerothcore/azerothcore-wotlk) server with custom modules that I use on a fresh Debian VM (debian-13.6.0 by 09/08/26).

* **System & Dependencies**: Updates Debian and installs all required packages (`git`, `curl`, `unzip`, `p7zip-full`, `sudo`, `tmux`, `net-tools`, `php`, `php-mysqli`).
* **SSH & GRUB Optimization**: 
  * Configures SSH to allow root access if needed.
  * Tweaks **GRUB** settings (`GRUB_DEFAULT=1` and `GRUB_TIMEOUT=0`) to speed up system boot times by skipping the boot menu.
* **Network Configuration**: Automatically detects your network interface, reads the current configuration, and sets up a **static IP address** and DNS settings to ensure stable connectivity.
* **Core & Modules Management**: 
  * Clones the main AzerothCore repository (Playerbot branch).
  * Automatically adds and integrates the custom modules that I use: 
    * [`mod-individual-progression`](https://github.com/azerothcore/mod-individual-progression)
    * [`mod-ah-bot`](https://github.com/azerothcore/mod-ah-bot)
    * [`mod-dungeon-clear`](https://github.com/azerothcore/mod-dungeon-clear)
    * [`mod-multibot-bridge`](https://github.com/azerothcore/mod-multibot-bridge)
    * [`mod-account-mounts`](https://github.com/azerothcore/mod-account-mounts)
* **Server Management & `tmux` Integration**: 
  * Generates a `/root/start.sh` script that automatically launches both the `authserver` and `worldserver` inside isolated `tmux` sessions (`auth-session` and `world-session`).
* **Custom Bash Aliases**: Configures useful shortcuts in `.bashrc` for daily management:
  * `wow`: Instantly attaches to the live `worldserver` `tmux` session.
  * `auth`: Instantly attaches to the `authserver` `tmux` session.
  * `start`: Quickly executes the `start.sh` script to boot up the server.
  * `stop`: Gracefully shuts down all running `tmux` server sessions (`tmux kill-server`).
  * `compile` / `build`: Shortcuts to compile or rebuild the server via `./acore.sh`.
  * `update`: Pulls the latest updates from the main repository and Playerbots.
  * `pb`, `world`, `ah`: Direct shortcuts to quickly edit configuration files (`playerbots.conf`, `worldserver.conf`, `mod_ahbot.conf`) using `nano`.
  * `qqq`: Instant server shutdown shortcut (`sudo shutdown now`).
* **Compilation & Next Steps**: 
  * Runs the dependency installer (`./acore.sh install-deps`) and triggers the full compilation process.
  * *Note*: After compilation, you still need to configure your databases, set up your AHBot accounts, and finalize the server setup.

i follow this guide https://youtu.be/UG900F19GPk. Thank you, nirv!
