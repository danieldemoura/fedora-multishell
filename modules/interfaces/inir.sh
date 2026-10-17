#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/shells/inir.sh
# Submódulo: Provedor e compilador do Desktop Shell iNiR
# ==============================================================================
set -euo pipefail

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

# 1. Instalação do Quickshell via DNF (COPR errornointernet/quickshell)
CONF_FILE="${INSTALLER_ROOT}/config/packages-inir.conf"
install_packages_from_conf "${CONF_FILE}"

# 2. Provisionamento defensivo do runtime Deno em /usr/local/bin/deno
# Baixado diretamente no $REAL_HOME para não esgotar blocos/inodes na tmpfs do /tmp
if ! command -v deno &>/dev/null; then
    log_info "Provisionando defensivamente o binário oficial do Deno..."
    DENO_TMP_ZIP="${REAL_HOME}/deno-install-temp.zip"
    curl -fsSL "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip" -o "${DENO_TMP_ZIP}"
    sudo unzip -o "${DENO_TMP_ZIP}" -d /usr/local/bin/
    sudo chmod +x /usr/local/bin/deno
    rm -f "${DENO_TMP_ZIP}"
    log_success "Deno $(/usr/local/bin/deno --version | head -n1) instalado com sucesso em /usr/local/bin/deno."
else
    log_info "Runtime Deno já detectado no sistema: $(deno --version | head -n1)"
fi

# 3. Renovação antecipada do sudo
log_info "Renovando timestamp administrativo do sudo..."
sudo -v

# 4. Clonagem do repositório do iNiR
INIR_DIR="${REAL_HOME}/.config/inir"
if [[ ! -d "${INIR_DIR}" ]]; then
    log_info "Clonando repositório do iNiR em ${INIR_DIR}..."
    sudo -u "${REAL_USER}" mkdir -p "${REAL_HOME}/.config"
    sudo -u "${REAL_USER}" git clone https://github.com/snowarch/inir.git "${INIR_DIR}"
    log_success "Repositório do iNiR clonado com sucesso."
else
    log_info "Diretório do iNiR já existente em ${INIR_DIR}. Prosseguindo..."
fi

# 5. Execução não-interativa sob usuário real
if [[ -f "${INIR_DIR}/setup" ]]; then
    log_info "Executando instalação não-interativa do iNiR sob o usuário ${REAL_USER}..."
    sudo -u "${REAL_USER}" chmod +x "${INIR_DIR}/setup"
    sudo -u "${REAL_USER}" bash -c "cd '${REAL_HOME}/.config/inir' && ./setup install -y"
    log_success "Instalação do iNiR concluída com sucesso."
else
    log_error "Script de instalação ./setup não encontrado em ${INIR_DIR}!"
    exit 1
fi

# 6. Correção de propriedade
log_info "Ajustando propriedade e permissões de ${INIR_DIR}..."
sudo chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.config/inir"
log_success "Submódulo iNiR Shell configurado com sucesso."
