#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/03_desktop_apps.sh
# Instalação de aplicações desktop, Brave Origin, codecs e Loja GNOME Software
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

ui_section_header "MÓDULO 03: APLICAÇÕES DE USUÁRIO E MULTIMÍDIA"

# 1. Instalação dos Aplicativos do Usuário e Codecs
log_info "Sincronizando ffmpeg com repositório RPM Fusion (swap ffmpeg-free -> ffmpeg)..."
sudo dnf swap -y --allowerasing ffmpeg-free ffmpeg || true

log_info "Instalando aplicações desktop e utilitários multimídia..."
install_packages_from_conf "${PACKAGES_DIR}/apps.conf" "--allowerasing"

# 2. Instalação do Navegador Brave Origin (com contingência oficial)
log_info "Instalando navegador web Brave Origin (sem IA/crypto)..."
if ! install_packages_from_conf "${PACKAGES_DIR}/brave.conf" "--allowerasing"; then
    log_warn "brave-origin não encontrado diretamente nos repositórios DNF. Disparando instalador oficial via curl..."
    # O instalador oficial da Brave escreve em /etc/yum.repos.d e portanto exige
    # privilégios de root. É baixado na home do usuário (nunca em /tmp) e
    # executado via sudo com a variável FLAVOR preservada.
    BRAVE_INSTALLER_TMP="${HOME:-/tmp}/brave-install-$$.sh"
    if curl -fsSL https://dl.brave.com/install.sh -o "${BRAVE_INSTALLER_TMP}" \
        && sudo env "FLAVOR=origin" bash "${BRAVE_INSTALLER_TMP}"; then
        log_success "Brave Origin instalado com sucesso via instalador oficial."
    else
        log_warn "Falha no script de instalação do Brave Origin. Tentando pacote brave-browser padrão via contingência..."
        sudo dnf install -y --allowerasing brave-browser || log_warn "Não foi possível instalar pacote do Brave via DNF."
    fi
    rm -f "${BRAVE_INSTALLER_TMP}"
else
    log_success "Brave Origin instalado com sucesso via DNF."
fi

# 3. Remoção do Atalho Legado WebApp do Flathub (substituído pela Loja Nativa GNOME Software)
LEGACY_FLATHUB_DESKTOP="/usr/share/applications/flathub-store.desktop"
if [[ -f "$LEGACY_FLATHUB_DESKTOP" ]]; then
    log_info "Removendo atalho legado da WebApp do Flathub (${LEGACY_FLATHUB_DESKTOP})..."
    sudo rm -f "$LEGACY_FLATHUB_DESKTOP"
    log_success "Atalho legado ${LEGACY_FLATHUB_DESKTOP} excluído com sucesso."
fi

# 4. Loja Gráfica de Aplicativos Nativa (GNOME Software e repositório Flathub)
# O pacote gnome-software já é coberto declarativamente por apps.conf (etapa 1);
# aqui apenas garante-se o remote Flathub ativo para a loja gráfica.
log_info "Garantindo repositório Flathub ativo para o GNOME Software..."
if command -v flatpak >/dev/null 2>&1; then
    sudo flatpak remote-add --if-not-exists flathub "${REPO_FLATHUB_URL}" || true
fi
log_success "Loja Gráfica GNOME Software e integração Flathub configuradas."

# 5. Instalação Declarativa de Aplicativos Flatpak
FLATPAK_CONF="${PACKAGES_DIR}/flatpak.conf"
if [[ -f "$FLATPAK_CONF" ]] && command -v flatpak >/dev/null 2>&1; then
    log_info "Instalando aplicativos declarativos via Flatpak (Flathub)..."
    while read -r app_id override_args || [[ -n "$app_id" ]]; do
        app_id="$(echo "$app_id" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$app_id" || "$app_id" =~ ^# ]] && continue

        log_info "Instalando Flatpak: ${app_id}..."
        if ! sudo flatpak install -y flathub "$app_id"; then
            log_warn "Falha ao instalar Flatpak: ${app_id}"
            continue
        fi

        # Overrides de permissão declarados no manifesto (tokens após o app_id)
        if [[ -n "${override_args:-}" ]]; then
            log_info "Aplicando permissões extras (${override_args}) para ${app_id}..."
            # shellcheck disable=SC2086
            sudo flatpak override "$app_id" ${override_args} || log_warn "Falha ao aplicar override em ${app_id}."
        fi
    done < "$FLATPAK_CONF"
fi

log_success "Módulo 03 (Aplicações Desktop) concluído com sucesso."
