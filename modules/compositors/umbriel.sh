#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/compositors/umbriel.sh
# Submódulo: Instalação do Compositor Umbriel, Xwayland-satellite e Portais XDG
# ==============================================================================
set -euo pipefail

install_packages_from_conf "${PACKAGES_DIR}/umbriel.conf"

log_success "Submódulo Umbriel configurado com sucesso."
