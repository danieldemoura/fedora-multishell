#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/compositors/umbriel.sh
# Submódulo: Instalação do Compositor Umbriel, Xwayland-satellite e Portais XDG
# ==============================================================================
set -euo pipefail

log_info "Instalando Umbriel Nightly, Xwayland-satellite e portais de desktop..."
sudo dnf install -y \
    umbriel-nightly \
    xwayland-satellite \
    xdg-desktop-portal-umbriel-nightly \
    xdg-desktop-portal-gtk

log_success "Submódulo Umbriel configurado com sucesso."
