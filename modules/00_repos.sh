#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/00_repos.sh
# Configuração e ativação de repositórios oficiais e de terceiros (RPM Fusion, COPRs, Brave, Flathub)
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

ui_section_header "MÓDULO 00: CONFIGURAÇÃO DE REPOSITÓRIOS"

FEDORA_VER="$(rpm -E %fedora)"
log_info "Detectada distribuição: Fedora ${FEDORA_VER}"

# 1. Instalação do RPM Fusion Free e Nonfree
log_info "Configurando repositórios RPM Fusion (Free & Nonfree)..."
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
log_success "RPM Fusion configurado com sucesso."

# 2. Habilitação de plugins do DNF (dnf-plugins-core necessário para copr e config-manager)
log_info "Garantindo suporte a plugins do DNF (dnf-plugins-core)..."
sudo dnf install -y dnf-plugins-core

# 3. Habilitação Condicional de Repositórios conforme a Seleção do Usuário
enable_copr_repo() {
    local copr_name="$1"
    local repo_file_pattern="$2"

    log_info "Verificando repositório COPR: ${copr_name}..."
    if ls /etc/yum.repos.d/*"${repo_file_pattern}"*.repo >/dev/null 2>&1 || dnf repolist --enabled 2>/dev/null | grep -qi "${repo_file_pattern}"; then
        log_info "Repositório COPR '${copr_name}' já está habilitado. Pulando..."
    else
        log_info "Habilitando repositório COPR '${copr_name}'..."
        sudo dnf copr enable -y "${copr_name}"
        log_success "Repositório COPR '${copr_name}' habilitado com sucesso."
    fi
}

# Se o compositor for Niri: ativa o COPR yalter/niri
if [[ "${SELECTED_COMPOSITOR:-niri}" == "niri" ]]; then
    enable_copr_repo "yalter/niri" "yalter:niri"
fi

# Se a shell for iNiR: ativa o COPR errornointernet/quickshell
if [[ "${SELECTED_SHELL:-inir}" == "inir" ]]; then
    enable_copr_repo "errornointernet/quickshell" "errornointernet:quickshell"
fi

# Se a shell escolhida for Noctalia: ativa o repositório Terra do Fyra Labs (necessário para o noctalia-greeter e umbriel)
if [[ "${SELECTED_SHELL:-}" == "noctalia" || "${SELECTED_INTERFACE:-}" == "noctalia" ]]; then
    log_info "Verificando repositório Terra do Fyra Labs para Noctalia Shell e dependências (noctalia-greeter / umbriel)..."
    if rpm -q terra-release >/dev/null 2>&1 || ls /etc/yum.repos.d/*terra*.repo >/dev/null 2>&1; then
        log_info "Repositório Terra do Fyra Labs já está configurado. Pulando..."
    else
        # O --nogpgcheck abaixo é o bootstrap OFICIAL documentado pela Fyra Labs
        # (https://docs.terrapkg.com/usage/installing): necessário apenas para
        # instalar terra-release/terra-gpg-keys (ovo-e-galinha da chave GPG).
        # Ele é estritamente restrito a esses dois pacotes; toda instalação
        # posterior do Terra é assinada e verificada normalmente.
        log_info "Instalando pacotes de bootstrap do repositório Terra (terra-release e terra-gpg-keys)..."
        if ! sudo dnf install -y --nogpgcheck --repofrompath "terra,${REPO_TERRA_URL}" \
            terra-release terra-gpg-keys; then
            log_warn "Tentativa via repofrompath falhou. Tentando download direto dos pacotes RPM do Terra..."
            if ! sudo dnf install -y \
                "https://repos.fyralabs.com/terra${FEDORA_VER}/terra-release.rpm" \
                "https://repos.fyralabs.com/terra${FEDORA_VER}/terra-gpg-keys.rpm"; then
                log_error "Falha ao configurar o repositório Terra (obrigatório para noctalia-greeter/umbriel)."
                exit 1
            fi
        fi
        log_success "Repositório Terra do Fyra Labs configurado com sucesso."
    fi
fi

# Se a interface escolhida for DankLinux: ativa o COPR avengemedia/danklinux
if [[ "${SELECTED_INTERFACE:-}" == "danklinux" || "${SELECTED_SHELL:-}" == "danklinux" ]]; then
    enable_copr_repo "avengemedia/danklinux" "avengemedia:danklinux"
fi

# 4. Instalação do Repositório Brave Software
log_info "Configurando repositório oficial do Brave Browser..."
if dnf config-manager --help 2>&1 | grep -q "addrepo"; then
    sudo dnf config-manager addrepo --from-repofile="${REPO_BRAVE_URL}" || true
elif dnf config-manager --help 2>&1 | grep -q -- "--add-repo"; then
    sudo dnf config-manager --add-repo "${REPO_BRAVE_URL}" || true
else
    sudo curl -fsSL "${REPO_BRAVE_URL}" -o /etc/yum.repos.d/brave-browser.repo
fi
log_success "Repositório Brave configurado com sucesso."

# 5. Habilitação do Flathub Oficial
log_info "Configurando Flatpak e repositório Flathub..."
sudo dnf install -y flatpak
sudo flatpak remote-add --if-not-exists flathub "${REPO_FLATHUB_URL}" || true
log_success "Repositório Flathub adicionado com sucesso."

# 6. Atualização e Sincronização dos Metadados
log_info "Atualizando índices e cache dos repositórios..."
sudo dnf upgrade --refresh -y
log_success "Módulo 00 (Repositórios) concluído com sucesso."
