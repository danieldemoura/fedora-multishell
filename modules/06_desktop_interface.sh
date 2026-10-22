#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/06_desktop_interface.sh
# Roteador / Despachante da Camada de Desktop Shell
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

ui_section_header "MÓDULO 06: INTERFACE GRÁFICA (DESKTOP SHELL)"

SELECTED_INTERFACE="${SELECTED_INTERFACE:-${SELECTED_SHELL:-inir}}"
SELECTED_SHELL="${SELECTED_INTERFACE}"

case "${SELECTED_INTERFACE}" in
    inir)
        log_info "Ativando submódulo da interface: iNiR"
        # shellcheck source=interfaces/inir.sh
        source "${SCRIPT_DIR}/interfaces/inir.sh"
        ;;
    noctalia)
        log_info "Ativando submódulo da interface: Noctalia"
        # shellcheck source=interfaces/noctalia.sh
        source "${SCRIPT_DIR}/interfaces/noctalia.sh"
        ;;
    duxshell)
        log_info "Ativando submódulo da interface: Dux Shell (DMS)"
        # shellcheck source=interfaces/duxshell.sh
        source "${SCRIPT_DIR}/interfaces/duxshell.sh"
        ;;
    *)
        log_error "Interface gráfica desconhecida: ${SELECTED_INTERFACE}"
        exit 1
        ;;
esac

log_success "Módulo 06 (Interface Gráfica) concluído com sucesso."
