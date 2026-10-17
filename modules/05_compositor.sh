#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/05_compositor.sh
# Roteador / Despachante da Camada de Compositor Wayland
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Carrega bibliotecas e configurações se executado isoladamente
# shellcheck source=../config/settings.conf
[[ -f "${INSTALLER_ROOT}/config/settings.conf" ]] && source "${INSTALLER_ROOT}/config/settings.conf"
# shellcheck source=../lib/ui.sh
[[ -f "${INSTALLER_ROOT}/lib/ui.sh" ]] && source "${INSTALLER_ROOT}/lib/ui.sh"
# shellcheck source=../lib/logger.sh
[[ -f "${INSTALLER_ROOT}/lib/logger.sh" ]] && source "${INSTALLER_ROOT}/lib/logger.sh"
# shellcheck source=../lib/utils.sh
[[ -f "${INSTALLER_ROOT}/lib/utils.sh" ]] && source "${INSTALLER_ROOT}/lib/utils.sh"

ui_section_header "MÓDULO 05: COMPOSITOR WAYLAND"



# Despachante modular (Padrão Strategy)
SELECTED_COMPOSITOR="${SELECTED_COMPOSITOR:-niri}"

if [ "${SELECTED_COMPOSITOR}" = "niri" ]; then
    log_info "Ativando submódulo do compositor: Niri"
    # shellcheck source=compositors/niri.sh
    source "${SCRIPT_DIR}/compositors/niri.sh"
elif [ "${SELECTED_COMPOSITOR}" = "umbriel" ]; then
    log_info "Ativando submódulo do compositor: Umbriel"
    # shellcheck source=compositors/umbriel.sh
    source "${SCRIPT_DIR}/compositors/umbriel.sh"
else
    log_error "Compositor desconhecido: ${SELECTED_COMPOSITOR}"
    exit 1
fi

log_success "Módulo 05 (Compositor Wayland) concluído com sucesso."
