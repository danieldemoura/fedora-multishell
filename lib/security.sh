#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: lib/security.sh
# Módulo de Segurança Defensiva: privilégios, integridade criptográfica e cadeia de suprimentos
# ==============================================================================
set -euo pipefail

# 1. Limpeza defensiva de regras temporárias de sudoers em /etc/sudoers.d/
security_cleanup_sudoers_temp() {
    local sudoers_temp="/etc/sudoers.d/99-fedora-installer-temp"
    if sudo test -f "${sudoers_temp}" 2>/dev/null; then
        log_warn "Removendo preventivamente regra temporária residual de sudoers (${sudoers_temp})..."
        sudo rm -f "${sudoers_temp}" 2>/dev/null || true
    fi
}

# 2. Inicialização de keep-alive do sudo em memória
# Mantém o timestamp do sudo atualizado a cada 50 segundos em background,
# atrelado à vida do processo pai ($$), sem criar arquivos permissivos NOPASSWD no disco.
security_init_sudo_keepalive() {
    log_info "Validando privilégios administrativos iniciais (sudo)..."
    if ! sudo -v; then
        log_error "Falha ao obter privilégios de sudo. O usuário atual deve pertencer ao grupo wheel."
        exit 1
    fi

    # Dispara loop em background que renova o timestamp em memória enquanto o processo pai ($$) existir
    (
        while true; do
            sudo -n true
            sleep 50
            kill -0 "$$" || exit
        done 2>/dev/null
    ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'cleanup_installer' EXIT HUP INT TERM
    log_success "Keep-alive de sudo em memória ativado (PID: ${SUDO_KEEPALIVE_PID}, sem persistência em disco)."
}

# 3. Importação defensiva e validação de chave pública GPG de repositório externo
security_import_repo_key() {
    local key_url="$1"
    if [[ -z "${key_url}" ]]; then
        log_error "URL de chave GPG não informada para security_import_repo_key."
        return 1
    fi

    log_info "Importando chave pública GPG para verificação de repositório: ${key_url}..."
    if sudo rpm --import "${key_url}"; then
        log_success "Chave pública GPG importada com sucesso: ${key_url}"
    else
        log_error "Falha ao importar chave pública GPG: ${key_url}"
        return 1
    fi
}

# 4. Checkout seguro da release estável mais recente via Git semântico
security_checkout_latest_release() {
    local repo_path="$1"
    if [[ ! -d "${repo_path}" ]]; then
        log_error "Diretório de repositório não encontrado: ${repo_path}"
        return 1
    fi

    pushd "${repo_path}" >/dev/null
    local latest_tag
    latest_tag="$(git tag -l --sort=-v:refname "v*" | head -n 1)"
    if [[ -n "${latest_tag}" ]]; then
        log_info "Mudando para a última release estável lançada: ${latest_tag}"
        git checkout "${latest_tag}"
    else
        log_warn "Nenhuma tag de release encontrada. Mantendo branch padrão testada."
    fi
    popd >/dev/null
}
