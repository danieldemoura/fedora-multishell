#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: lib/utils.sh
# Funções utilitárias: validações, permissões e manipulação segura de manifests
# ==============================================================================

# Impede a execução direta do script como root (Segurança / Seção 1.2 da especificação)
check_not_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        echo -e "\e[1;31m[ERRO] Não execute este script diretamente com sudo ou como usuário root!\e[0m" >&2
        echo -e "Execute como seu usuário comum: \e[1;36m./install.sh\e[0m" >&2
        echo -e "O script solicitará privilégios administrativos (sudo) internamente quando necessário." >&2
        exit 1
    fi
}

# Obtém o usuário real (preservando o contexto SUDO_USER quando aplicável)
get_real_user() {
    local target_user="${SUDO_USER:-${USER:-$(id -un)}}"
    echo "$target_user"
}

# Resolve a home do usuário real via base de contas (getent), sem eval:
# eval sobre nome de usuário permitiria injeção de código via $USER/$SUDO_USER.
get_real_user_home() {
    local target_user home
    target_user="$(get_real_user)"
    home="$(getent passwd "$target_user" | cut -d: -f6)"

    if [[ -z "$home" ]]; then
        log_error "Não foi possível resolver o diretório home do usuário '${target_user}'."
        return 1
    fi
    echo "$home"
}

# Garante que arquivos criados pertençam ao usuário comum, nunca a root:root
ensure_user_ownership() {
    local target_path="$1"
    local real_user
    real_user="$(get_real_user)"

    if [[ -e "$target_path" ]]; then
        sudo chown -R "${real_user}:${real_user}" "$target_path"
    fi
}

# Limpeza global de encerramento do script (usada pelo trap de install.sh).
# Remove o drop-in temporário de sudoers e artefatos de build residuais.
cleanup_installer() {
    local exit_code=$?
    if [[ -n "${SUDOERS_BUILD_TMP:-}" ]]; then
        rm -f "${SUDOERS_BUILD_TMP}" 2>/dev/null || true
    fi
    if [[ -n "${SUDOERS_TEMP:-}" ]]; then
        sudo rm -f "${SUDOERS_TEMP}" 2>/dev/null || true
    fi
    exit "${exit_code}"
}

# Valida conectividade com a Internet
check_internet() {
    log_info "Verificando conexão com a internet..."
    local test_hosts=("1.1.1.1" "8.8.8.8" "fedoraproject.org")
    local connected=false

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            connected=true
            break
        fi
    done

    if [[ "$connected" != true ]]; then
        if curl -fsI --connect-timeout 5 https://fedoraproject.org >/dev/null 2>&1; then
            connected=true
        fi
    fi

    if [[ "$connected" != true ]]; then
        log_error "Sem conexão com a internet detectada. Verifique o cabo de rede ou Wi-Fi antes de prosseguir."
        exit 1
    fi
    log_success "Conectividade com a internet confirmada."
}

# Cria backup seguro do arquivo apenas se não houver um backup prévio
backup_file() {
    local file="$1"
    local use_sudo="${2:-false}"

    if [[ -f "$file" ]] && [[ ! -f "${file}.bak" ]]; then
        if [[ "$use_sudo" == true ]]; then
            sudo cp "$file" "${file}.bak"
        else
            cp "$file" "${file}.bak"
        fi
        log_info "Backup criado: ${file}.bak"
    fi
}

# Instala pacotes declarados em arquivo .conf (ignora linhas vazias e comentários #).
# Manifesto ausente é tratado como ERRO: um typo de caminho não pode silenciar
# a instalação de uma camada inteira (auditabilidade IaC / Seção 1.2 da especificação).
install_packages_from_conf() {
    local conf_file="$1"
    local extra_args="${2:-}"

    if [[ ! -f "$conf_file" ]]; then
        log_error "Manifesto declarativo não encontrado: ${conf_file}"
        return 1
    fi

    local pkgs=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        pkgs+=("$line")
    done < "$conf_file"

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Instalando pacotes declarados em $(basename "$conf_file")..."
        # shellcheck disable=SC2086
        sudo dnf install -y ${extra_args} "${pkgs[@]}"
    fi
}
