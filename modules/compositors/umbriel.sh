#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/compositors/umbriel.sh
# Submódulo: Instalação do Compositor Umbriel, Xwayland-satellite e Portais XDG
# ==============================================================================
set -euo pipefail

CONF_FILE="${INSTALLER_ROOT}/config/packages-umbriel.conf"
install_packages_from_conf "${CONF_FILE}"

log_success "Submódulo Umbriel configurado com sucesso."
