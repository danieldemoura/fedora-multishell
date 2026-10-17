#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/compositors/niri.sh
# Submódulo: Instalação do Compositor Niri, Xwayland-satellite e Portais XDG
# ==============================================================================
set -euo pipefail

install_packages_from_conf "${CONFIG_DIR}/packages-niri.conf" "--exclude=alacritty"

# Remoção defensiva caso o Alacritty já esteja presente no sistema
sudo dnf remove -y alacritty 2>/dev/null || true

log_info "Configurando integração e prioridades de portais XDG para Niri..."
sudo mkdir -p /usr/share/xdg-desktop-portal/portals
sudo mkdir -p /etc/xdg/xdg-desktop-portal

sudo tee /etc/xdg/xdg-desktop-portal/niri-portals.conf >/dev/null <<'EOF'
[preferred]
default=gtk;gnome;
org.freedesktop.impl.portal.ScreenCast=gnome;
org.freedesktop.impl.portal.Screenshot=gnome;
EOF

log_success "Submódulo Niri configurado com sucesso."
