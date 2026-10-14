#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/compositors/niri.sh
# Submódulo: Instalação do Compositor Niri, Xwayland-satellite e Portais XDG
# ==============================================================================
set -euo pipefail

log_info "Instalando Niri, Xwayland-satellite e portais de desktop via DNF..."
sudo dnf install -y \
    niri \
    xwayland-satellite \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk

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
