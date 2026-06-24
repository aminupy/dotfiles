# Dotfiles

Personal dotfiles for Ubuntu 24.04 LTS — i3 window manager, Zsh, Alacritty, and more.

## Contents

```
dotfiles/
├── install.sh            # Provisioning script (idempotent)
├── packages.txt          # apt packages to install
├── README.md             # This file
├── home/
│   ├── .bashrc           # Bash config
│   ├── .bash_profile     # Auto-start X on tty1
│   ├── .profile          # Login shell config
│   ├── .zshrc            # Zsh config (with zoxide, autosuggestions, syntax highlighting)
│   ├── .gitconfig        # Git user config
│   ├── .xinitrc          # X11 startup → i3
│   └── .cargo/env        # Rust/Cargo environment
└── config/
    ├── i3/config              # i3 window manager
    ├── i3status-rust/config.toml  # Status bar
    ├── picom/picom.conf       # Compositor
    ├── alacritty/             # Alacritty terminal
    ├── kitty/kitty.conf       # Kitty terminal
    ├── rofi/                  # App launcher
    ├── btop/btop.conf         # System monitor
    ├── fontconfig/fonts.conf  # Font config
    └── gtk-3.0/bookmarks      # File manager bookmarks
```

## Quick Start

```bash
# Clone and run
cd ~/dotfiles
./install.sh
```

On a fresh system, you'll need `git` and `curl` first:

```bash
sudo apt update && sudo apt install -y git curl
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles && ./install.sh
```

## Usage

```
./install.sh            # Interactive mode — prompts before overwriting files
./install.sh -y         # Non-interactive — auto-backups existing files
./install.sh --help     # Show help
```

The script is **idempotent** — safe to run multiple times. It will:

1. Install all packages from `packages.txt` via `apt`
2. Create required directories (`~/.config/`, `~/.local/bin/`, etc.)
3. Symlink home dotfiles (`.zshrc`, `.bashrc`, `.gitconfig`, etc.)
4. Symlink XDG config files into `~/.config/`
5. Apply system tweaks (swappiness, cache pressure)

Existing files are backed up to `~/dotfiles-backup-<timestamp>/`.

## Manual Steps Required

### 1. External Repositories

`packages.txt` includes packages from these external repos — install them first:

- **Google Chrome**: https://www.google.com/chrome/
- **VS Code**: https://code.visualstudio.com/download
- **WezTerm**: https://wezfurlong.org/wezterm/installation.html
- **Typora**: https://typora.io/#linux
- **Obsidian**: https://obsidian.md/download
- **Tor Browser**: via `torbrowser-launcher` (auto-downloads)
- **Docker**: may need docker's official repo — https://docs.docker.com/engine/install/ubuntu/

### 2. Rust Toolchain

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install lsd i3status-rust
```

### 3. Nerd Font

The configs use **JetBrainsMono Nerd Font**. Install via:

```bash
# Option A: Download from https://www.nerdfonts.com/font-downloads
# Option B: Install via script
mkdir -p ~/.local/share/fonts
wget -O ~/.local/share/fonts/JetBrainsMono.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip ~/.local/share/fonts/JetBrainsMono.zip -d ~/.local/share/fonts/
fc-cache -fv
```

### 4. Neovim

Currently not configured in this repo. Install via:

```bash
# Download pre-built binary
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
```

### 5. Zsh as Default Shell

```bash
chsh -s $(which zsh)
```

Log out and back in for changes to take effect.

### 6. Wallpaper

Update the wallpaper path in `config/i3/config`:

```
exec_always --no-startup-id feh --bg-fill ~/Pictures/1.jpg
```

### 7. Git Config

Your name/email is already in `.gitconfig`. If you have project-specific git configs
(like `includeIf` directives), add them after setup.

### 8. Secrets

The script sources `~/.config/secrets/env.zsh` if it exists. Create this file for
private environment variables (API keys, tokens, etc.) — it is NOT tracked in this repo.

## System Tweaks Applied

| Setting | Value | Benefit |
|---|---|---|
| `vm.swappiness` | 10 | Less swap usage on SSD |
| `vm.vfs_cache_pressure` | 50 | Keep dentry/inode caches longer |

## Customizing

- Edit files in `~/dotfiles/` — they are symlinked, so changes take effect immediately.
- After changing packages, add/remove entries in `packages.txt`.
- Run `./install.sh` again to sync new files.
