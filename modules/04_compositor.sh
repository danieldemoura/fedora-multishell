#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/04_compositor.sh
# Instalação do Compositor Niri, Quickshell, Xwayland-satellite e Portais XDG
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

ui_section_header "MÓDULO 04: COMPOSITOR NIRI E PONTES DE SISTEMA"

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

# 1. Provisionamento preventivo do runtime Deno em /usr/local/bin/deno
# Baixado diretamente na pasta pessoal ($REAL_HOME) para não esgotar blocos/inodes na tmpfs do /tmp
if ! command -v deno &>/dev/null; then
    log_info "Provisionando preventivamente o runtime oficial do Deno..."
    DENO_TMP_ZIP="${REAL_HOME}/deno-install-temp.zip"
    curl -fsSL "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip" -o "${DENO_TMP_ZIP}"
    sudo unzip -o "${DENO_TMP_ZIP}" -d /usr/local/bin/
    sudo chmod +x /usr/local/bin/deno
    rm -f "${DENO_TMP_ZIP}"
    log_success "Deno $(/usr/local/bin/deno --version | head -n1) instalado com sucesso em /usr/local/bin/deno."
else
    log_info "Runtime Deno já detectado no sistema: $(deno --version | head -n1)"
fi

# 2. Instalação via DNF dos Componentes do Compositor e Pontes de Sistema
log_info "Instalando Niri, Quickshell, Xwayland-satellite, Portais e utilitários de sessão via DNF..."
sudo dnf install -y \
    niri \
    quickshell \
    xwayland-satellite \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    git \
    polkit \
    gnome-keyring \
    swaylock

# 3. Configuração do arquivo de portais em /etc/xdg/xdg-desktop-portal/niri-portals.conf
log_info "Configurando integração e prioridades de portais XDG para Niri..."
sudo mkdir -p /usr/share/xdg-desktop-portal/portals
sudo mkdir -p /etc/xdg/xdg-desktop-portal

sudo tee /etc/xdg/xdg-desktop-portal/niri-portals.conf >/dev/null <<'EOF'
[preferred]
default=gtk;gnome;
org.freedesktop.impl.portal.ScreenCast=gnome;
org.freedesktop.impl.portal.Screenshot=gnome;
EOF

log_success "Arquivo /etc/xdg/xdg-desktop-portal/niri-portals.conf configurado."

log_success "Módulo 04 (Compositor Niri e Pontes de Sistema) concluído com sucesso."
