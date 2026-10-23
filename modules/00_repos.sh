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

# 0.1 Hardening IPv4 em VMs: muitas VMs (rede NAT com IPv6 semi-configurado) têm
# stack IPv6 em modo "blackhole" — consultas DNS/AAAA e conexões IPv6 travam, e o
# librepo/curl aborta com "Curl error (6): Could not resolve host" ou timeouts. Forçar
# IPv4 no dnf (ip_resolve=4, global — vale também para o ./setup install do iNiR) e no
# curl do usuário (--ipv4 em ~/.curlrc) elimina essa classe de falha. Só em IS_VM=true
# para não penalizar bare metal (que pode ter IPv6 funcional ou até IPv6-only).
if [[ "${IS_VM:-false}" == true ]]; then
    if ! sudo grep -qE '^ip_resolve' "$DNF_CONF" 2>/dev/null; then
        log_info "VM detectada: forçando resolução/conexão IPv4 no DNF (ip_resolve=4)..."
        sudo sed -i '/^\[main\]/a ip_resolve=4' "$DNF_CONF"
        log_success "ip_resolve=4 habilitado em ${DNF_CONF}."
    fi
    REAL_USER_00="$(get_real_user)"
    CURLRC_00="$(get_real_user_home)/.curlrc"
    if ! grep -qE '^[[:space:]]*--ipv4' "$CURLRC_00" 2>/dev/null; then
        log_info "VM detectada: forçando IPv4 no curl do usuário (--ipv4 em ${CURLRC_00})..."
        printf '%s\n' '--ipv4' | sudo -u "${REAL_USER_00}" tee -a "$CURLRC_00" >/dev/null
        log_success "--ipv4 adicionado a ${CURLRC_00}."
    fi
fi

# 1. Instalação do RPM Fusion Free e Nonfree
# download1.rpmfusion.org é o servidor-mestre DIRETO (o mesmo usado como
# baseurl nos .repo oficiais, sem roleta de mirrors). Já mirrors.rpmfusion.org
# redireciona cada requisição para um mirror "sorteado" — mas o MirrorManager
# faz steering geográfico: se o mirror designado para a região do usuário
# estiver fora do ar, TODAS as requisições caem no mesmo mirror morto.
# Estratégia: mestre direto primeiro; se falhar, retentativas na roleta
# (que pode acertar outro mirror), alternando IPv4 puro nas tentativas
# pares (VMs com IPv6 blackhole travam o SYN de TCP até o timeout).
fetch_rpm_with_fallback() {
    local dest="$1" url_direto="$2" url_roleta="$3" attempts="${4:-5}" i url fonte extra=()
    for ((i = 1; i <= attempts; i++)); do
        if (( i == 1 )); then
            url="$url_direto"; fonte="servidor-mestre direto"
        else
            url="$url_roleta"; fonte="mirror da roleta"
            if (( i % 2 == 0 )); then extra=(--ipv4); fonte+=", forçando IPv4"; else extra=(); fi
        fi
        log_info "Baixando $(basename "$dest") (tentativa ${i}/${attempts}: ${fonte})..."
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
    if fetch_rpm_with_fallback "$RF_FREE" \
         "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
         "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" &&
       fetch_rpm_with_fallback "$RF_NONFREE" \
         "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
         "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"; then
        sudo dnf install -y "$RF_FREE" "$RF_NONFREE"
        log_success "RPM Fusion configurado com sucesso."
    else
        log_error "Falha ao baixar os release RPMs do RPM Fusion (servidor-mestre e roleta de mirrors inacessíveis)."
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

# Se a interface escolhida for Dux Shell: ativa o COPR avengemedia/danklinux
# (Os COPRs novos duxlabs/dux e duxlabs/dms ainda não estão prontos para produção,
# conforme aviso oficial na página dos repositórios — manter avengemedia até o 2.0.1)
if [[ "${SELECTED_INTERFACE:-}" == "duxshell" || "${SELECTED_SHELL:-}" == "duxshell" ]]; then
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
