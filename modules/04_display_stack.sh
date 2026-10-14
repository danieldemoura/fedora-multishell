#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/04_display_stack.sh
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

SELECTED_SHELL="${SELECTED_SHELL:-inir}"
IS_VM="${IS_VM:-false}"

if [[ "${SELECTED_SHELL}" == "noctalia" ]]; then
    ui_section_header "MÓDULO 04: PILHA DO DISPLAY MANAGER E LOGIN (GREETD / NOCTALIA GREETER)"

    # 1. Instalação do Greetd, Greetd SELinux e Noctalia Greeter
    log_info "Instalando greetd, greetd-selinux e noctalia-greeter via DNF..."
    sudo dnf install -y greetd greetd-selinux noctalia-greeter gnome-keyring-pam

    # 2. Permissões de hardware para o usuário greetd
    log_info "Configurando permissões de hardware (video, render, input) para o usuário greetd..."
    sudo usermod -aG video,render,input greetd 2>/dev/null || true

    # 3. Configuração do /etc/greetd/config.toml a partir do template
    log_info "Configurando /etc/greetd/config.toml..."
    sudo mkdir -p /etc/greetd
    GREETD_CONFIG="/etc/greetd/config.toml"
    GREETD_TEMPLATE="${INSTALLER_ROOT}/templates/greetd.toml.template"

    if [[ -f "$GREETD_CONFIG" ]]; then
        backup_file "$GREETD_CONFIG" true
    fi

    if [[ "${IS_VM}" == true ]]; then
        GREETER_CMD="env LIBGL_ALWAYS_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 /usr/bin/noctalia-greeter-session"
    else
        GREETER_CMD="/usr/bin/noctalia-greeter-session"
    fi

    if [[ -f "$GREETD_TEMPLATE" ]]; then
        sed "s|__GREETD_COMMAND__|${GREETER_CMD}|g" "$GREETD_TEMPLATE" | sudo tee "$GREETD_CONFIG" >/dev/null
    else
        sudo tee "$GREETD_CONFIG" >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "${GREETER_CMD}"
user = "greetd"
EOF
    fi
    log_success "Arquivo ${GREETD_CONFIG} gerado com sucesso."

    # 4. Configuração do PAM (/etc/pam.d/greetd) a partir de templates/pam_greetd.template
    log_info "Configurando integração PAM no Greetd para desbloqueio do cofre de senhas..."
    PAM_GREETD="/etc/pam.d/greetd"
    PAM_GREETD_TEMPLATE="${INSTALLER_ROOT}/templates/pam_greetd.template"

    if [[ -f "$PAM_GREETD" ]]; then
        backup_file "$PAM_GREETD" true
    fi

    if [[ -f "$PAM_GREETD_TEMPLATE" ]]; then
        sudo cp "$PAM_GREETD_TEMPLATE" "$PAM_GREETD"
    else
        sudo tee "$PAM_GREETD" >/dev/null <<'EOF'
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
    fi
    log_success "Arquivo ${PAM_GREETD} configurado com suporte ao pam_gnome_keyring."

    log_success "Módulo 04 (Display Stack - Greetd) concluído com sucesso."

else
    ui_section_header "MÓDULO 04: PILHA DO DISPLAY MANAGER E LOGIN (SDDM)"

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
        if [[ -f "${INSTALLER_ROOT}/templates/pam_sddm.template" ]] && grep -q "auth" "${INSTALLER_ROOT}/templates/pam_sddm.template"; then
            sudo cp "${INSTALLER_ROOT}/templates/pam_sddm.template" "$PAM_SDDM"
        else
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
        fi
        log_success "Arquivo ${PAM_SDDM} criado com suporte ao pam_gnome_keyring."
    fi

    log_success "Módulo 04 (Display Stack - SDDM) concluído com sucesso."
fi
