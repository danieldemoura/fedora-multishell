#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/04_display_stack.sh
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

SELECTED_INTERFACE="${SELECTED_INTERFACE:-${SELECTED_SHELL:-inir}}"
SELECTED_SHELL="${SELECTED_INTERFACE}"
IS_VM="${IS_VM:-false}"
REAL_USER="$(get_real_user)"

if [[ "${SELECTED_INTERFACE}" =~ ^(danklinux|noctalia)$ || "${SELECTED_SHELL}" =~ ^(danklinux|noctalia)$ ]]; then
    ui_section_header "MÓDULO 04: PILHA DO DISPLAY MANAGER E LOGIN (GREETD)"

    # 1. Instalação declarativa dos pacotes base do Greetd e GNOME Keyring PAM
    install_packages_from_conf "${PACKAGES_DIR}/greetd.conf"

    # 2. Permissões de hardware para o usuário greetd
    log_info "Configurando permissões de hardware (video, render, input) para o usuário greetd..."
    sudo usermod -aG video,render,input greetd 2>/dev/null || true

    # 3. Provisionamento específico do Noctalia Greeter (se interface for noctalia)
    if [[ "${SELECTED_INTERFACE}" == "noctalia" || "${SELECTED_SHELL}" == "noctalia" ]]; then
        install_packages_from_conf "${PACKAGES_DIR}/noctalia.conf"

        log_info "Configurando diretório de estado e autorização do Noctalia Greeter..."
        sudo mkdir -p /var/lib/noctalia-greeter
        sudo chown -R greetd:greetd /var/lib/noctalia-greeter
        sudo noctalia-greeter passwordless-sync enable "${REAL_USER}"
        log_success "Sincronização de aparência (passwordless-sync) ativada para '${REAL_USER}'."

        log_info "Configurando /etc/greetd/config.toml..."
        sudo mkdir -p /etc/greetd
        GREETD_CONFIG="/etc/greetd/config.toml"
        GREETD_TEMPLATE="${SYSTEM_DIR}/greetd.toml.template"

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
    fi

    # 4. Configuração defensiva do PAM (/etc/pam.d/greetd)
    log_info "Configurando integração PAM no Greetd para desbloqueio do cofre de senhas..."
    PAM_GREETD="/etc/pam.d/greetd"
    PAM_GREETD_TEMPLATE="${SYSTEM_DIR}/pam_greetd.template"

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
    sudo chmod 644 "$PAM_GREETD"
    sudo chown root:root "$PAM_GREETD"
    log_success "Arquivo ${PAM_GREETD} configurado com suporte ao pam_gnome_keyring (permissão 644)."

    log_success "Módulo 04 (Display Stack - Greetd) concluído com sucesso."

else
    ui_section_header "MÓDULO 04: PILHA DO DISPLAY MANAGER E LOGIN (SDDM)"

    # 1. Instalação declarativa do SDDM e Módulo PAM GNOME Keyring
    install_packages_from_conf "${PACKAGES_DIR}/sddm.conf"

    # 2. Permissões de hardware para o usuário do sddm
    log_info "Configurando permissões de hardware (video, render, input) para o usuário sddm..."
    sudo usermod -aG video,render,input sddm 2>/dev/null || true

    # 3. Configuração do PAM (/etc/pam.d/sddm) para Desbloqueio do Gnome Keyring
    log_info "Configurando integração PAM no SDDM para desbloqueio automático do cofre de senhas..."
    PAM_SDDM="/etc/pam.d/sddm"
    PAM_SDDM_TEMPLATE="${SYSTEM_DIR}/pam_sddm.template"

    if [[ -f "$PAM_SDDM" ]]; then
        backup_file "$PAM_SDDM" true
        
        # Injeta 'auth optional pam_gnome_keyring.so' se não presente.
        # O awk lê o arquivo ATUAL (não o .bak): em reexecuções, o .bak pode ser
        # um snapshot antigo de outra sessão e restaurá-lo perderia alterações.
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
            ' "$PAM_SDDM" | sudo tee "${PAM_SDDM}.multishell.tmp" >/dev/null
            sudo mv -f "${PAM_SDDM}.multishell.tmp" "$PAM_SDDM"
            log_success "Diretivas do pam_gnome_keyring.so injetadas em ${PAM_SDDM}."
        else
            log_info "pam_gnome_keyring.so já configurado em ${PAM_SDDM}."
        fi
    else
        # Se o arquivo não existir, cria o arquivo com configuração padrão completa
        if [[ -f "$PAM_SDDM_TEMPLATE" ]] && grep -q "auth" "$PAM_SDDM_TEMPLATE"; then
            sudo cp "$PAM_SDDM_TEMPLATE" "$PAM_SDDM"
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
    sudo chmod 644 "$PAM_SDDM"
    sudo chown root:root "$PAM_SDDM"

    log_success "Módulo 04 (Display Stack - SDDM) concluído com sucesso."
fi
