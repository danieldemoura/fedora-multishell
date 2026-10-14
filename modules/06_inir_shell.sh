#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/06_inir_shell.sh
# Módulo Dedicado: Clonagem, compilação e configuração do Desktop Shell iNiR
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

ui_section_header "MÓDULO 06: DESKTOP SHELL iNiR"

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

# 1. Renovação Antecipada do Sudo
# Atualiza o timestamp administrativo para garantir que chamadas internas de sudo
# do instalador do iNiR herdem o acesso sem pausar o terminal pedindo senha ao usuário.
log_info "Renovando timestamp administrativo do sudo..."
sudo -v

# 2. Clonagem do Repositório do iNiR
INIR_DIR="${REAL_HOME}/.config/inir"

if [[ ! -d "${INIR_DIR}" ]]; then
    log_info "Clonando repositório do iNiR em ${INIR_DIR}..."
    sudo -u "${REAL_USER}" mkdir -p "${REAL_HOME}/.config"
    sudo -u "${REAL_USER}" git clone https://github.com/snowarch/inir.git "${INIR_DIR}"
    log_success "Repositório do iNiR clonado com sucesso."
else
    log_info "Diretório do iNiR já existente em ${INIR_DIR}. Prosseguindo..."
fi

# 3. Instalação Não-Interativa sob Usuário Real
if [[ -f "${INIR_DIR}/setup" ]]; then
    log_info "Executando instalação não-interativa do iNiR sob o usuário ${REAL_USER}..."
    sudo -u "${REAL_USER}" chmod +x "${INIR_DIR}/setup"
    sudo -u "${REAL_USER}" bash -c "cd '${REAL_HOME}/.config/inir' && ./setup install -y"
    log_success "Instalação do iNiR concluída com sucesso."
else
    log_error "Script de instalação ./setup não encontrado em ${INIR_DIR}!"
    exit 1
fi

# 4. Correção e Garantia de Permissões
log_info "Ajustando propriedade e permissões de ${INIR_DIR}..."
sudo chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.config/inir"
log_success "Permissões de ${REAL_HOME}/.config/inir atribuídas a ${REAL_USER}:${REAL_USER}."

log_success "Módulo 06 (Desktop Shell iNiR) concluído com sucesso."
