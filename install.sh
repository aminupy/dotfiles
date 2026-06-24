#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# install.sh — dotfiles provisioning script
# ============================================================================
# This script installs packages, creates directories, and symlinks dotfiles.
# It is idempotent — safe to run multiple times.
#
# Usage:
#   ./install.sh            # interactive (prompt before overwriting)
#   ./install.sh -y         # non-interactive (auto-backup existing files)
#   ./install.sh --help     # show help
# ============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
INTERACTIVE=true
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--force)
            INTERACTIVE=false
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [-y] [--help]"
            echo "  -y, --yes    Non-interactive mode — auto-backup existing files"
            echo "  --help       Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ============================================================================
# Utility functions
# ============================================================================

link_file() {
    local src="$1" dst="$2"

    mkdir -p "$(dirname "$dst")"

    if [[ ! -e "$src" ]]; then
        log_warn "Source '$src' does not exist — skipping"
        return
    fi

    if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
        log_ok "Symlink already correct: $dst → $src"
        return
    fi

    if [[ -f "$dst" ]] || [[ -d "$dst" ]] || [[ -L "$dst" ]]; then
        if [[ "$INTERACTIVE" == true ]]; then
            echo -en "${YELLOW}[?]${NC}    Overwrite '$dst'? [y/N/b(ackup)] "
            read -r answer
            case "$answer" in
                y|Y)
                    rm -rf "$dst"
                    log_info "Removed existing: $dst"
                    ;;
                b|B)
                    mkdir -p "$BACKUP_DIR"
                    mv "$dst" "$BACKUP_DIR/"
                    log_info "Backed up: $dst → $BACKUP_DIR/"
                    ;;
                *)
                    log_warn "Skipped: $dst"
                    return
                    ;;
            esac
        else
            mkdir -p "$BACKUP_DIR"
            mv "$dst" "$BACKUP_DIR/" 2>/dev/null || true
            log_info "Backed up: $dst → $BACKUP_DIR/"
        fi
    fi

    ln -s "$src" "$dst"
    log_ok "Linked: $dst → $src"
}

ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_ok "Created directory: $dir"
    fi
}

# ============================================================================
# Phase 0: Snap removal (Ubuntu ships snap by default)
# ============================================================================
remove_snap() {
    echo ""
    echo "======================================================"
    echo " Phase 0: Snap Removal"
    echo "======================================================"

    if ! command -v snap &>/dev/null; then
        log_ok "Snap is not installed — nothing to remove"
        return
    fi

    log_info "Snap detected — removing all snap packages and snapd..."

    # Remove all installed snap packages
    installed_snaps=$(snap list 2>/dev/null | awk 'NR>1 {print $1}')
    if [[ -n "$installed_snaps" ]]; then
        log_info "Removing snap packages..."
        while IFS= read -r snap_name; do
            sudo snap remove --purge "$snap_name" >/dev/null 2>&1 || true
            log_info "  Removed snap: $snap_name"
        done <<< "$installed_snaps"
    fi

    # Stop and disable snapd services
    log_info "Stopping snapd services..."
    sudo systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
    sudo systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

    # Purge snapd and related packages
    log_info "Purging snapd packages..."
    sudo apt-get purge -y snapd gnome-software-plugin-snap >/dev/null 2>&1 || true

    # Remove leftover directories
    log_info "Removing snap directories..."
    sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd
    rm -rf "$HOME/snap"

    # Prevent snapd from being installed accidentally
    log_info "Holding snapd to prevent reinstall..."
    sudo apt-mark hold snapd >/dev/null 2>&1 || true

    # Also remove Firefox snap if it was installed via snap
    if [[ -f /etc/apt/preferences.d/mozilla-firefox ]]; then
        log_info "Firefox PPA pinning already configured — snap Firefox won't return"
    fi

    log_ok "Snap fully removed and held"
}

# ============================================================================
# Phase 1: External repositories
# ============================================================================
add_external_repos() {
    echo ""
    echo "======================================================"
    echo " Phase 1: External Repositories"
    echo "======================================================"

    # --- Prerequisites ---
    log_info "Installing repo prerequisites..."
    sudo apt-get install -y curl ca-certificates gnupg software-properties-common >/dev/null 2>&1
    sudo mkdir -p /etc/apt/keyrings

    # --- Google Chrome ---
    if [[ ! -f /etc/apt/sources.list.d/google-chrome.list ]]; then
        log_info "Adding Google Chrome repository..."
        if curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
            | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg; then
            echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
                | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
            log_ok "Google Chrome repo added"
        else
            log_warn "Failed to add Google Chrome repository — skipping"
        fi
    else
        log_ok "Google Chrome repo already present"
    fi

    # --- Firefox (Mozilla PPA — deb version, not snap) ---
    if [[ ! -f /etc/apt/sources.list.d/mozillateam-ubuntu-ppa-noble.sources ]]; then
        log_info "Adding Mozilla Team PPA (Firefox)..."
        sudo add-apt-repository -y -n ppa:mozillateam/ppa >/dev/null 2>&1
        # Pin to prefer PPA over snap
        echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' | sudo tee /etc/apt/preferences.d/mozilla-firefox >/dev/null
        log_ok "Firefox PPA added"
    else
        log_ok "Firefox PPA already present"
    fi

    # --- Docker (official repo) ---
    if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
        log_info "Adding Docker repository..."
        if curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
            log_ok "Docker repo added"
        else
            log_warn "Failed to add Docker repository — skipping"
        fi
    else
        log_ok "Docker repo already present"
    fi
}

# ============================================================================
# Phase 2: System package installation
# ============================================================================
install_packages() {
    local pkg_file="$REPO_DIR/packages.txt"

    if [[ ! -f "$pkg_file" ]]; then
        log_warn "packages.txt not found — skipping package installation"
        return
    fi
    echo ""
    echo "======================================================"
    echo " Phase 2: System Packages"
    echo "======================================================"

    local packages
    packages=$(grep -v '^\s*#' "$pkg_file" | tr '\n' ' ')

    if [[ -z "$packages" ]]; then
        log_warn "No packages listed in packages.txt — skipping"
        return
    fi

    log_info "Updating package lists..."
    sudo apt-get update -qq

    log_info "Installing packages..."
    sudo apt-get install -y $packages

    log_ok "Package installation complete"
}

# ============================================================================
# Phase 3: Create required directories
# ============================================================================
setup_directories() {
    echo ""
    echo "======================================================"
    echo " Phase 3: Directory Setup"
    echo "======================================================"

    local dirs=(
        "$HOME/.config"
        "$HOME/.local/bin"
        "$HOME/.local/share/fonts"
        "$HOME/Scripts"
        "$HOME/Projects"
    )

    for dir in "${dirs[@]}"; do
        ensure_directory "$dir"
    done

    log_ok "Directory setup complete"
}

# ============================================================================
# Phase 4: Symlink home dotfiles
# ============================================================================
link_home_files() {
    echo ""
    echo "======================================================"
    echo " Phase 4: Home Dotfiles"
    echo "======================================================"

    local home_files=(
        ".bashrc"
        ".bash_profile"
        ".profile"
        ".zshrc"
        ".gitconfig"
        ".xinitrc"
    )

    for file in "${home_files[@]}"; do
        link_file "$REPO_DIR/home/$file" "$HOME/$file"
    done

    # .cargo/env
    link_file "$REPO_DIR/home/.cargo/env" "$HOME/.cargo/env"
}

# ============================================================================
# Phase 5: Symlink XDG config files
# ============================================================================
link_config_files() {
    echo ""
    echo "======================================================"
    echo " Phase 5: XDG Config Files"
    echo "======================================================"

    declare -A config_links
    config_links["i3/config"]="i3/config"
    config_links["i3status-rust/config.toml"]="i3status-rust/config.toml"
    config_links["picom/picom.conf"]="picom/picom.conf"
    config_links["alacritty/alacritty.toml"]="alacritty/alacritty.toml"
    config_links["alacritty/alacritty.yml"]="alacritty/alacritty.yml"
    config_links["kitty/kitty.conf"]="kitty/kitty.conf"
    config_links["rofi/config.rasi"]="rofi/config.rasi"
    config_links["rofi/gruvbox-material.rasi"]="rofi/gruvbox-material.rasi"
    config_links["btop/btop.conf"]="btop/btop.conf"
    config_links["fontconfig/fonts.conf"]="fontconfig/fonts.conf"
    config_links["gtk-3.0/bookmarks"]="gtk-3.0/bookmarks"

    for src_rel in "${!config_links[@]}"; do
        local src="$REPO_DIR/config/$src_rel"
        local dst="$HOME/.config/${config_links[$src_rel]}"
        link_file "$src" "$dst"
    done
}

# ============================================================================
# Phase 6: System tweaks (sysctl, swap, etc.)
# ============================================================================
apply_system_tweaks() {
    echo ""
    echo "======================================================"
    echo " Phase 6: System Tweaks"
    echo "======================================================"

    local sysctl_changes=false

    # --- swappiness (reduce — better for SSDs) ---
    local current_swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    if [[ "$current_swappiness" -gt 10 ]]; then
        log_info "Setting vm.swappiness = 10 (was $current_swappiness)"
        echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/90-swappiness.conf >/dev/null
        sudo sysctl -w vm.swappiness=10 >/dev/null
        sysctl_changes=true
        log_ok "Swappiness set to 10"
    else
        log_ok "Swappiness already optimal ($current_swappiness)"
    fi

    # --- vfs_cache_pressure ---
    local current_cache_pressure
    current_cache_pressure=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo "100")
    if [[ "$current_cache_pressure" != "50" ]]; then
        log_info "Setting vm.vfs_cache_pressure = 50 (was $current_cache_pressure)"
        echo "vm.vfs_cache_pressure=50" | sudo tee /etc/sysctl.d/90-cache-pressure.conf >/dev/null
        sudo sysctl -w vm.vfs_cache_pressure=50 >/dev/null
        sysctl_changes=true
        log_ok "vfs_cache_pressure set to 50"
    else
        log_ok "vfs_cache_pressure already optimal ($current_cache_pressure)"
    fi

    if [[ "$sysctl_changes" == false ]]; then
        log_info "No sysctl changes needed"
    fi

    # --- Check if zswap/zram is active ---
    if [[ -d /sys/module/zswap ]]; then
        log_info "ZSWAP is active"
    fi
    if command -v zramctl &>/dev/null && zramctl 2>/dev/null | grep -q "zram"; then
        log_info "ZRAM is active"
    fi

    log_ok "System tweaks applied"
}

# ============================================================================
# Phase 7: Nerd Fonts installation
# ============================================================================
install_fonts() {
    echo ""
    echo "======================================================"
    echo " Phase 7: Nerd Fonts"
    echo "======================================================"

    local font_dir="$HOME/.local/share/fonts"
    local jetbrains_zip="$font_dir/JetBrainsMono.zip"
    local jetbrains_marker="$font_dir/.jetbrains-nerdfont-installed"

    mkdir -p "$font_dir"

    if [[ -f "$jetbrains_marker" ]]; then
        log_ok "JetBrainsMono Nerd Font already installed"
    else
        log_info "Downloading JetBrainsMono Nerd Font..."
        if curl -fsSL -o "$jetbrains_zip" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
            log_info "Extracting to $font_dir..."
            unzip -qo "$jetbrains_zip" -d "$font_dir"
            rm -f "$jetbrains_zip"
            # Remove Windows metadata files
            rm -f "$font_dir"/*.txt "$font_dir"/*.md "$font_dir"/readme*
            touch "$jetbrains_marker"
            log_ok "JetBrainsMono Nerd Font installed"
        else
            log_warn "Failed to download JetBrainsMono Nerd Font — skipping"
        fi
    fi

    # Rebuild font cache
    if command -v fc-cache &>/dev/null; then
        log_info "Rebuilding font cache..."
        fc-cache -fv "$font_dir" >/dev/null 2>&1
        log_ok "Font cache updated"
    fi
}

# ============================================================================
# Phase 8: Docker user setup
# ============================================================================
setup_docker() {
    echo ""
    echo "======================================================"
    echo " Phase 8: Docker User Setup"
    echo "======================================================"

    if command -v docker &>/dev/null; then
        if id -nG "$USER" 2>/dev/null | grep -qw docker; then
            log_ok "User '$USER' is already in the docker group"
        else
            log_info "Adding user '$USER' to the docker group..."
            sudo groupadd docker 2>/dev/null || true
            sudo usermod -aG docker "$USER"
            log_ok "User added to docker group (relogin to take effect)"
        fi
    else
        log_warn "Docker is not installed — skipping group setup"
    fi
}

# ============================================================================
# Phase 9: Post-install hints
# ============================================================================
show_post_install_hints() {
    echo ""
    echo "======================================================"
    echo " Phase 9: Post-Install Hints"
    echo "======================================================"

    local missing=()

    # Check for tools not available via apt
    command -v cargo &>/dev/null || missing+=("rust/cargo (https://rustup.rs)")
    command -v go &>/dev/null || missing+=("go (https://go.dev/dl/)")
    command -v node &>/dev/null && node --version &>/dev/null || missing+=("node/npm (via nvm or volta)")
    command -v nvim &>/dev/null || missing+=("neovim (https://github.com/neovim/neovim)")
    command -v wezterm &>/dev/null || missing+=("wezterm (https://wezfurlong.org/wezterm/)")
    command -v lsd &>/dev/null || missing+=("lsd (cargo install lsd)")
    command -v i3status-rs &>/dev/null || missing+=("i3status-rust (cargo install i3status-rs)")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "The following tools need manual installation:"
        for tool in "${missing[@]}"; do
            echo "       - $tool"
        done
    else
        log_ok "All tools detected!"
    fi

    echo ""
    echo "======================================================"
    echo " Setup Complete!"
    echo "======================================================"
    echo ""
    echo "  Dotfiles repo : $REPO_DIR"
    echo "  Backups       : $BACKUP_DIR"
    echo ""
    echo "  Next steps:"
    echo "    1. Restart your shell:  exec zsh"
    echo "    2. Or log out and back in"
    echo "    3. Install missing tools listed above"
    echo ""
}

# ============================================================================
# Main
# ============================================================================
main() {
    echo ""
    echo "======================================================"
    echo " Dotfiles Installer"
    echo " Repository: $REPO_DIR"
    echo " Date:      $(date)"
    echo "======================================================"

    remove_snap
    add_external_repos
    install_packages
    setup_directories
    link_home_files
    link_config_files
    apply_system_tweaks
    install_fonts
    setup_docker
    show_post_install_hints
}

main "$@"
