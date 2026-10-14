#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/03_display_stack.sh
# Instalação e configuração do SDDM e PAM Keyring
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

ui_section_header "MÓDULO 03: PILHA DO DISPLAY MANAGER E LOGIN (SDDM)"

# 1. Instalação do SDDM e Módulo PAM GNOME Keyring
log_info "Instalando sddm e gnome-keyring-pam via DNF..."
sudo dnf install -y sddm gnome-keyring-pam

# 2. Permissões de hardware para o usuário do sddm
log_info "Configurando permissões de hardware (video, render, input) para o usuário sddm..."
sudo usermod -aG video,render,input sddm 2>/dev/null || true

# 3. Configuração do PAM (/etc/pam.d/sddm) para Desbloqueio do Gnome Keyring
log_info "Configurando integração PAM no SDDM para desbloqueio automático do cofre de senhas..."
PAM_SDDM="/etc/pam.d/sddm"

if [[ -f "$PAM_SDDM" ]]; then
    backup_file "$PAM_SDDM" true
    
    # Injeta 'auth optional pam_gnome_keyring.so' se não presente
    if ! sudo grep -q "pam_gnome_keyring.so" "$PAM_SDDM"; then
        sudo awk '
            BEGIN { auth_added=0; sess_added=0 }
            /^auth/ && !auth_added {
                print
                print "auth       optional    pam_gnome_keyring.so"
                auth_added=1
                next
            }
            /^session/ && !sess_added {
                print
                print "session    optional    pam_gnome_keyring.so auto_start"
                sess_added=1
                next
            }
            { print }
        ' "${PAM_SDDM}.bak" | sudo tee "$PAM_SDDM" >/dev/null
        log_success "Diretivas do pam_gnome_keyring.so injetadas em ${PAM_SDDM}."
    else
        log_info "pam_gnome_keyring.so já configurado em ${PAM_SDDM}."
    fi
else
    # Se o arquivo não existir, cria o arquivo com configuração padrão completa
    sudo tee "$PAM_SDDM" >/dev/null <<'EOF'
#%PAM-1.0
auth     [success=done ignore=ignore default=bad] pam_selinux_permit.so
auth     substack     password-auth
auth     optional     pam_gnome_keyring.so
-auth    optional     pam_kwallet5.so

account  include      password-auth

password include      password-auth

session  required     pam_selinux.so close
session  required     pam_loginuid.so
session  required     pam_selinux.so open
session  optional     pam_keyinit.so force revoke
session  include      password-auth
session  optional     pam_gnome_keyring.so auto_start
-session optional     pam_kwallet5.so auto_start
EOF
    log_success "Arquivo ${PAM_SDDM} criado com suporte ao pam_gnome_keyring."
fi

log_success "Módulo 03 (Display Stack - SDDM) concluído com sucesso."
