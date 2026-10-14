#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/04_compositor_shell.sh
# Instalação do Compositor Niri, Quickshell, Xwayland-satellite, Desktop Shell iNiR e Portais
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

ui_section_header "MÓDULO 04: COMPOSITOR, SHELL E PORTAIS XDG"

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

# 1. Garantia das Dependências de Compilação e Runtimes do iNiR
log_info "Garantindo dependências essenciais de compilação e execução do iNiR..."
sudo dnf install -y \
    python3.12 \
    python3.12-devel \
    cairo-devel \
    cairo-gobject-devel \
    gobject-introspection-devel \
    unzip \
    socat \
    mpv

# 2. Pré-instalação defensiva do runtime Deno para o iNiR
if ! command -v deno &>/dev/null; then
    log_info "Pré-instalando runtime oficial do Deno para o iNiR..."
    DENO_TMP_ZIP="${REAL_HOME}/deno-install-temp.zip"
    # Baixa direto na pasta pessoal para não esgotar blocos/inodes na tmpfs do /tmp
    curl -fsSL "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip" -o "${DENO_TMP_ZIP}"
    sudo unzip -o "${DENO_TMP_ZIP}" -d /usr/local/bin/
    sudo chmod +x /usr/local/bin/deno
    rm -f "${DENO_TMP_ZIP}"
    log_success "Deno $(/usr/local/bin/deno --version | head -n1) instalado com sucesso em /usr/local/bin/deno."
else
    log_info "Runtime Deno já detectado no sistema: $(deno --version | head -n1)"
fi

# 3. Instalação dos Componentes Centrais da Interface Wayland
log_info "Instalando Niri, Quickshell, Xwayland-satellite e Portais XDG via DNF..."
sudo dnf install -y \
    niri \
    quickshell \
    xwayland-satellite \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome \
    git \
    polkit \
    gnome-keyring \
    libsecret \
    swaylock

# 4. Configuração de Prioridade dos Portais XDG para a Sessão Niri
log_info "Configurando integração e prioridades de portais XDG..."
sudo mkdir -p /usr/share/xdg-desktop-portal/portals
sudo mkdir -p /etc/xdg/xdg-desktop-portal

# Garante fallback ordenado para sessões Niri
sudo tee /etc/xdg/xdg-desktop-portal/niri-portals.conf >/dev/null <<'EOF'
[preferred]
default=gtk;gnome;
org.freedesktop.impl.portal.ScreenCast=gnome;
org.freedesktop.impl.portal.Screenshot=gnome;
EOF

log_success "Portais XDG configurados."

# 5. Instalação do Desktop Shell iNiR
log_info "Configurando Desktop Shell iNiR para o usuário: ${REAL_USER}..."
INIR_DIR="${REAL_HOME}/.config/inir"

if [[ -d "${INIR_DIR}/.git" ]]; then
    log_info "Repositório do iNiR já clonado em ${INIR_DIR}. Atualizando..."
    sudo -u "${REAL_USER}" git -C "${INIR_DIR}" pull --ff-only || true
elif [[ -d "${INIR_DIR}" ]]; then
    log_warn "Diretório ${INIR_DIR} já existe, mas não é um repositório git. Fazendo backup..."
    sudo -u "${REAL_USER}" mv "${INIR_DIR}" "${INIR_DIR}.bak.$(date +%s)"
    sudo -u "${REAL_USER}" git clone https://github.com/snowarch/inir.git "${INIR_DIR}"
else
    sudo -u "${REAL_USER}" mkdir -p "${REAL_HOME}/.config"
    sudo -u "${REAL_USER}" git clone https://github.com/snowarch/inir.git "${INIR_DIR}"
fi

# Execução do instalador nativo do iNiR em modo não-interativo sob o usuário real
if [[ -f "${INIR_DIR}/setup" ]]; then
    log_info "Executando instalador nativo do iNiR (./setup install -y)..."
    sudo -u "${REAL_USER}" chmod +x "${INIR_DIR}/setup"
    sudo -u "${REAL_USER}" bash -c "cd '${INIR_DIR}' && ./setup install -y"
    log_success "Instalador nativo do iNiR executado com sucesso."
else
    log_warn "Script ./setup não encontrado em ${INIR_DIR}."
fi

# Garante que o diretório clonado e suas dependências pertençam a REAL_USER:REAL_USER
ensure_user_ownership "${REAL_HOME}/.config"

log_success "Módulo 04 (Compositor e Shell) concluído com sucesso."
