#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/00_repos.sh
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

# 3. Habilitação dos Repositórios Fedora COPR (Niri e Quickshell) com Idempotência
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

enable_copr_repo "yalter/niri" "yalter:niri"
enable_copr_repo "errornointernet/quickshell" "errornointernet:quickshell"

# 4. Instalação do Repositório Brave Software
log_info "Configurando repositório oficial do Brave Browser..."
if dnf config-manager --help 2>&1 | grep -q "addrepo"; then
    sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
elif dnf config-manager --help 2>&1 | grep -q -- "--add-repo"; then
    sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
else
    sudo curl -fsSL https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo -o /etc/yum.repos.d/brave-browser.repo
fi
log_success "Repositório Brave configurado com sucesso."

# 5. Habilitação do Flathub Oficial
log_info "Configurando Flatpak e repositório Flathub..."
sudo dnf install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
log_success "Repositório Flathub adicionado com sucesso."

# 6. Atualização e Sincronização dos Metadados
log_info "Atualizando índices e cache dos repositórios..."
sudo dnf upgrade --refresh -y
log_success "Módulo 00 (Repositórios) concluído com sucesso."
