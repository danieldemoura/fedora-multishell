#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/interfaces/inir.sh
# Submódulo: Provedor e compilador do Desktop Shell iNiR
# ==============================================================================
set -euo pipefail

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

# 1. Instalação declarativa das dependências e do Quickshell via DNF
install_packages_from_conf "${PACKAGES_DIR}/inir.conf"

# 2. Provisionamento defensivo do runtime Deno em /usr/local/bin/deno
# Baixado diretamente no $REAL_HOME para não esgotar blocos/inodes na tmpfs do /tmp.
# O alvo de arquitetura é detectado via `uname -m` e o binário é validado contra
# o checksum SHA-256 publicado na própria release oficial do Deno.
if ! command -v deno &>/dev/null; then
    log_info "Provisionando defensivamente o binário oficial do Deno..."
    DENO_ARCH="$(uname -m)"
    case "${DENO_ARCH}" in
        x86_64)  DENO_TARGET="x86_64-unknown-linux-gnu" ;;
        aarch64) DENO_TARGET="aarch64-unknown-linux-gnu" ;;
        *)
            log_error "Arquitetura '${DENO_ARCH}' não suportada para o runtime Deno oficial."
            exit 1
            ;;
    esac

    DENO_ASSET="deno-${DENO_TARGET}.zip"
    DENO_BASE_URL="https://github.com/denoland/deno/releases/latest/download"
    DENO_TMP_ZIP="${REAL_HOME}/deno-install-temp.zip"
    DENO_TMP_SHA="${REAL_HOME}/deno-install-temp.zip.sha256sum"

    # A release do Deno publica o checksum por asset com o sufixo ".sha256sum"
    # (ex.: deno-x86_64-unknown-linux-gnu.zip.sha256sum) — nao ".sha256".
    if ! curl -fsSL "${DENO_BASE_URL}/${DENO_ASSET}" -o "${DENO_TMP_ZIP}"; then
        log_error "Falha ao baixar o binario do Deno: ${DENO_BASE_URL}/${DENO_ASSET}"
        exit 1
    fi
    if ! curl -fsSL "${DENO_BASE_URL}/${DENO_ASSET}.sha256sum" -o "${DENO_TMP_SHA}"; then
        log_error "Falha ao baixar o checksum do Deno: ${DENO_BASE_URL}/${DENO_ASSET}.sha256sum"
        rm -f "${DENO_TMP_ZIP}"
        exit 1
    fi

    DENO_EXPECTED_SHA="$(grep -Eo '[a-fA-F0-9]{64}' "${DENO_TMP_SHA}" | head -n1)"
    DENO_ACTUAL_SHA="$(sha256sum "${DENO_TMP_ZIP}" | cut -d' ' -f1)"
    if [[ -z "${DENO_EXPECTED_SHA}" ]] || [[ "${DENO_EXPECTED_SHA}" != "${DENO_ACTUAL_SHA}" ]]; then
        log_error "Verificação de integridade (SHA-256) do Deno falhou. Abortando instalação do iNiR."
        rm -f "${DENO_TMP_ZIP}" "${DENO_TMP_SHA}"
        exit 1
    fi
    log_info "Checksum SHA-256 do Deno confirmado."

    sudo unzip -o "${DENO_TMP_ZIP}" -d /usr/local/bin/
    sudo chmod +x /usr/local/bin/deno
    rm -f "${DENO_TMP_ZIP}" "${DENO_TMP_SHA}"
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
    # O pacote `uv` do Fedora traz uma configuração com python-downloads="manual",
    # o que faz o `uv venv --prompt ii-venv <venv> -p 3.12` do iNiR falhar: o Fedora 44
    # não traz um interpretador Python 3.12 no sistema e o uv está impedido de baixá-lo
    # automaticamente. Sobrescrevemos via ambiente (que tem precedência sobre o config
    # file do uv) para permitir o download do Python gerenciado 3.12 durante o venv.
    sudo -u "${REAL_USER}" env UV_PYTHON_DOWNLOADS=automatic bash -c "cd '${REAL_HOME}/.config/inir' && ./setup install -y"
    log_success "Instalação do iNiR concluída com sucesso."
else
    log_error "Script de instalação ./setup não encontrado em ${INIR_DIR}!"
    exit 1
fi

# 6. Correção de propriedade
log_info "Ajustando propriedade e permissões de ${INIR_DIR}..."
sudo chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.config/inir"
log_success "Submódulo iNiR Shell configurado com sucesso."
