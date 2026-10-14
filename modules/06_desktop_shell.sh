#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/06_desktop_shell.sh
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

SELECTED_SHELL="${SELECTED_SHELL:-inir}"

if [ "${SELECTED_SHELL}" = "inir" ]; then
    log_info "Ativando submódulo da shell: iNiR"
    # shellcheck source=shells/inir.sh
    source "${SCRIPT_DIR}/shells/inir.sh"
elif [ "${SELECTED_SHELL}" = "noctalia" ]; then
    log_info "Ativando submódulo da shell: Noctalia"
    # shellcheck source=shells/noctalia.sh
    source "${SCRIPT_DIR}/shells/noctalia.sh"
else
    log_error "Desktop Shell desconhecida: ${SELECTED_SHELL}"
    exit 1
fi

log_success "Módulo 06 (Interface Gráfica) concluído com sucesso."
