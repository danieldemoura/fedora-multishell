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

# 0. Otimização de Mirrors: habilita o plugin fastestmirror do DNF para que
# repositórios baseados em metalink (Fedora, RPM Fusion, COPRs) escolham o
# mirror de MENOR LATÊNCIA medida em runtime, em vez de um mirror sorteado
# aleatoriamente da lista global (sorteios já favoreceram mirrors caídos).
DNF_CONF="/etc/dnf/dnf.conf"
if ! sudo grep -qE '^fastestmirror' "$DNF_CONF" 2>/dev/null; then
    log_info "Habilitando fastestmirror no DNF (seleção do mirror mais próximo/veloz)..."
    sudo sed -i '/^\[main\]/a fastestmirror=True' "$DNF_CONF"
    log_success "fastestmirror habilitado em ${DNF_CONF}."
fi

# 1. Instalação do RPM Fusion Free e Nonfree
# O host mirrors.rpmfusion.org redireciona cada requisição para um mirror
# público ALEATÓRIO da lista global. Se o mirror sorteado estiver fora do ar,
# o dnf instala do URL falha; como cada nova tentativa de curl cai em outro
# mirror, baixamos os RPMs localmente com retentativas antes de instalar.
fetch_rpm_with_fallback() {
    local url="$1" dest="$2" attempts="${3:-5}" i extra=()
    for ((i = 1; i <= attempts; i++)); do
        # Alterna IPv6/dual-stack e IPv4 puro: VMs com IPv6 sem rota (blackhole)
        # travam o SYN de TCP até o timeout sem nunca testar o IPv4; o --ipv4
        # nas tentativas pares garante que esse cenário seja contornado.
        if (( i % 2 == 0 )); then extra=(--ipv4); else extra=(); fi
        log_info "Baixando $(basename "$url") (tentativa ${i}/${attempts}${extra:+, forçando IPv4} — mirror sorteado a cada tentativa)..."
        if curl -fL --connect-timeout 15 --max-time 180 ${extra[@]+"${extra[@]}"} "$url" -o "${dest}.part"; then
            mv -f "${dest}.part" "$dest"
            return 0
        fi
        rm -f "${dest}.part"
        sleep 2
    done
    return 1
}

log_info "Configurando repositórios RPM Fusion (Free & Nonfree)..."
if rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
    log_info "RPM Fusion já está configurado. Pulando..."
else
    # Download na Home do usuário (nunca em /tmp, que é tmpfs limitada em VMs)
    RPM_TMP_DIR="${HOME:-/tmp}/.fedora-multishell-rpm-$$"
    mkdir -p "$RPM_TMP_DIR"
    RF_FREE="${RPM_TMP_DIR}/rpmfusion-free-release.rpm"
    RF_NONFREE="${RPM_TMP_DIR}/rpmfusion-nonfree-release.rpm"
    if fetch_rpm_with_fallback "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" "$RF_FREE" &&
       fetch_rpm_with_fallback "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" "$RF_NONFREE"; then
        sudo dnf install -y "$RF_FREE" "$RF_NONFREE"
        log_success "RPM Fusion configurado com sucesso."
    else
        log_error "Falha ao baixar os release RPMs do RPM Fusion após múltiplas tentativas (todos os mirrors sorteados estavam inacessíveis)."
        rm -rf "$RPM_TMP_DIR"
        exit 1
    fi
    rm -rf "$RPM_TMP_DIR"
fi

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
