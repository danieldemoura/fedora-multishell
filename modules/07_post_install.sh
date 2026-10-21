#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/07_post_install.sh
# Configurações de pós-instalação: Keyring, Compositor config (Niri/Umbriel),
# autostart de Shell (iNiR/Noctalia), ABNT2, VM flags, target gráfico e testes
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

ui_section_header "MÓDULO 07: PÓS-INSTALAÇÃO E VALIDAÇÕES"

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"
SELECTED_COMPOSITOR="${SELECTED_COMPOSITOR:-niri}"
SELECTED_INTERFACE="${SELECTED_INTERFACE:-${SELECTED_SHELL:-inir}}"
SELECTED_SHELL="${SELECTED_INTERFACE}"

NIRI_CONFIG_DIR="${REAL_HOME}/.config/niri"
NIRI_CONFIG_FILE="${NIRI_CONFIG_DIR}/config.kdl"
UMB_CONFIG_DIR="${REAL_HOME}/.config/umbriel"
UMB_CONFIG_FILE="${UMB_CONFIG_DIR}/config.toml"

log_info "Executando ajustes pós-instalação para o usuário: ${REAL_USER} (${REAL_HOME})"
log_info "Configurações ativas -> Compositor: ${SELECTED_COMPOSITOR} | Shell: ${SELECTED_SHELL}"

# 1. Inicialização do cofre de credenciais e vínculo canônico com o PAM
log_info "Configurando integração silenciosa do GNOME Keyring com o PAM..."
KEYRINGS_DIR="${REAL_HOME}/.local/share/keyrings"
sudo -u "${REAL_USER}" mkdir -p "${KEYRINGS_DIR}"
sudo chmod 700 "${KEYRINGS_DIR}"

# Limpeza defensiva de chaveiros avulsos corrompidos gerados fora do PAM
sudo -u "${REAL_USER}" rm -f "${KEYRINGS_DIR}/Default_Keyring.keyring" "${KEYRINGS_DIR}/user.keystore"

# Define 'login' como o chaveiro padrão do sistema
echo "login" | sudo -u "${REAL_USER}" tee "${KEYRINGS_DIR}/default" >/dev/null
sudo chmod 600 "${KEYRINGS_DIR}/default"
sudo chown -R "${REAL_USER}:${REAL_USER}" "${KEYRINGS_DIR}"
log_success "Ponteiro do chaveiro canônico 'login' configurado em ${KEYRINGS_DIR}/default."

# 2. Configuração do Compositor Ativo (Niri ou Umbriel)
if [[ "${SELECTED_SHELL}" == "noctalia" ]]; then
    if [[ "${SELECTED_COMPOSITOR}" == "umbriel" ]]; then
        UMB_CONFIG_DIR="${REAL_HOME}/.config/umbriel"
        UMB_CONFIG_FILE="${UMB_CONFIG_DIR}/config.toml"

        log_info "Configurando ambiente do Umbriel para Noctalia a partir dos templates declarativos..."
        sudo -u "${REAL_USER}" mkdir -p "${UMB_CONFIG_DIR}"

        # Backup de config anterior se existir
        if [[ -f "${UMB_CONFIG_FILE}" ]]; then
            backup_file "${UMB_CONFIG_FILE}" false
        fi

        # Copia todos os arquivos declarativos de config/desktop/umbriel/* para ~/.config/umbriel/
        sudo -u "${REAL_USER}" cp -r "${DESKTOP_DIR}/umbriel/"* "${UMB_CONFIG_DIR}/"
        log_info "Configurações declarativas de Umbriel copiadas para ${UMB_CONFIG_DIR}/ com sucesso."

        # Respeita a escolha de teclado do usuário: os templates são distribuídos
        # com ABNT2; se a opção foi negada no menu, remove o layout "br".
        if [[ "${KEYBOARD_ABNT2:-true}" != true ]] && grep -qF 'layout = "br"' "${UMB_CONFIG_FILE}"; then
            log_info "ABNT2 não selecionado: removendo 'layout = \"br\"' de ${UMB_CONFIG_FILE}."
            sudo -u "${REAL_USER}" sed -i '/^layout = "br"/d' "${UMB_CONFIG_FILE}"
        fi

        # Injeção Dinâmica para VM: apenas se IS_VM=true (idempotente por guard de grep)
        if [[ "${IS_VM:-false}" == true ]]; then
            if ! grep -qF 'LIBGL_ALWAYS_SOFTWARE' "${UMB_CONFIG_FILE}"; then
                log_info "Detectado ambiente VM (IS_VM=true). Injetando parâmetros de renderização por software no Umbriel..."
                sudo -u "${REAL_USER}" tee -a "${UMB_CONFIG_FILE}" >/dev/null <<'EOF'

# ==============================================================================
# Ajustes automáticos para Máquina Virtual (VMware / VirtualBox)
[environment]
LIBGL_ALWAYS_SOFTWARE = "1"
WLR_NO_HARDWARE_CURSORS = "1"

[input.cursor]
hardware_cursor = false
EOF
                log_success "Flags de VM anexadas dinamicamente ao final de ${UMB_CONFIG_FILE}."
            else
                log_info "Flags de VM já presentes em ${UMB_CONFIG_FILE}."
            fi
        fi

        # Validação do arquivo final
        log_info "Executando validador oficial do Umbriel (umbriel config validate)..."
        if command -v umbriel >/dev/null 2>&1; then
            if UMB_VAL_OUTPUT="$(sudo -u "${REAL_USER}" umbriel config validate 2>&1)"; then
                log_success "[Checklist] Validação oficial aprovada: 'umbriel config validate' confirmou o arquivo de configuração."
            else
                log_warn "[Checklist] Aviso na validação do Umbriel: ${UMB_VAL_OUTPUT}"
            fi
        elif [[ -x "/usr/bin/umbriel" ]]; then
            if UMB_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/umbriel config validate 2>&1)"; then
                log_success "[Checklist] Validação oficial aprovada: '/usr/bin/umbriel config validate' confirmou o arquivo."
            else
                log_warn "[Checklist] Aviso na validação do Umbriel: ${UMB_VAL_OUTPUT}"
            fi
        else
            log_warn "[Checklist] Binário 'umbriel' não encontrado no PATH para executar a validação nativa imediata."
        fi

    elif [[ "${SELECTED_COMPOSITOR}" == "niri" ]]; then
        NIRI_CONFIG_DIR="${REAL_HOME}/.config/niri"
        NIRI_CONFIG_FILE="${NIRI_CONFIG_DIR}/config.kdl"

        log_info "Configurando ambiente do Niri para Noctalia a partir dos templates declarativos..."
        sudo -u "${REAL_USER}" mkdir -p "${NIRI_CONFIG_DIR}"

        # Backup de config anterior se existir
        if [[ -f "${NIRI_CONFIG_FILE}" ]]; then
            backup_file "${NIRI_CONFIG_FILE}" false
        fi

        # Copia configuração declarativa config/desktop/niri/config.kdl
        sudo -u "${REAL_USER}" cp "${DESKTOP_DIR}/niri/config.kdl" "${NIRI_CONFIG_FILE}"
        log_info "Configuração declarativa do Niri copiada para ${NIRI_CONFIG_FILE}."

        # Respeita a escolha de teclado do usuário: o template é distribuído com
        # ABNT2; se a opção foi negada no menu, remove o layout "br" do bloco xkb.
        if [[ "${KEYBOARD_ABNT2:-true}" != true ]] && grep -qF 'layout "br"' "${NIRI_CONFIG_FILE}"; then
            log_info "ABNT2 não selecionado: removendo 'layout \"br\"' de ${NIRI_CONFIG_FILE}."
            sudo -u "${REAL_USER}" sed -i '/layout "br"/d' "${NIRI_CONFIG_FILE}"
        fi

        # Injeção Dinâmica para VM: apenas se IS_VM=true (idempotente por guard de grep)
        if [[ "${IS_VM:-false}" == true ]]; then
            if ! grep -qF 'LIBGL_ALWAYS_SOFTWARE' "${NIRI_CONFIG_FILE}"; then
                log_info "Detectado ambiente VM (IS_VM=true). Injetando parâmetros de renderização por software no Niri..."
                sudo -u "${REAL_USER}" tee -a "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'

// =============================================================================
// Ajustes automáticos para Máquina Virtual (VMware / VirtualBox)
environment {
    LIBGL_ALWAYS_SOFTWARE "1"
    WLR_NO_HARDWARE_CURSORS "1"
}
EOF
                log_success "Flags de VM anexadas dinamicamente ao final de ${NIRI_CONFIG_FILE}."
            else
                log_info "Flags de VM já presentes em ${NIRI_CONFIG_FILE}."
            fi
        fi

        # Validação do arquivo final
        log_info "Executando validador oficial do Niri (niri validate)..."
        if command -v niri >/dev/null 2>&1; then
            if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate 2>&1)"; then
                log_success "[Checklist] Validação oficial aprovada: 'niri validate' confirmou o arquivo de configuração."
            else
                log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração!"
                while IFS= read -r val_line; do
                    log_error "  [niri validate] ${val_line}"
                done <<< "${NIRI_VAL_OUTPUT}"
                exit 1
            fi
        elif [[ -x "/usr/bin/niri" ]]; then
            if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate 2>&1)"; then
                log_success "[Checklist] Validação oficial aprovada: '/usr/bin/niri validate' confirmou o arquivo."
            else
                log_error "[Checklist] Falha crítica: '/usr/bin/niri validate' retornou erro na configuração!"
                while IFS= read -r val_line; do
                    log_error "  [niri validate] ${val_line}"
                done <<< "${NIRI_VAL_OUTPUT}"
                exit 1
            fi
        else
            log_warn "[Checklist] Binário 'niri' não encontrado no PATH para executar a validação nativa imediata."
        fi
    fi
elif [[ "${SELECTED_SHELL}" == "inir" ]]; then
    NIRI_CONFIG_DIR="${REAL_HOME}/.config/niri"
    NIRI_CONFIG_FILE="${NIRI_CONFIG_DIR}/config.kdl"

    log_info "Shell selecionada é o iNiR: configurando inicialização e integração no Niri..."
    sudo -u "${REAL_USER}" mkdir -p "${NIRI_CONFIG_DIR}"

    # Garante a existência do config.kdl (se não existir, cria vazio com permissões do usuário)
    if [[ ! -f "${NIRI_CONFIG_FILE}" ]]; then
        log_info "Arquivo ${NIRI_CONFIG_FILE} não encontrado. Criando arquivo base..."
        sudo -u "${REAL_USER}" touch "${NIRI_CONFIG_FILE}"
    fi

    # 1. Assegura injeção do comando de autostart do iNiR
    if ! grep -q 'spawn-at-startup "inir" "run"' "${NIRI_CONFIG_FILE}"; then
        log_info "Adicionando spawn-at-startup 'inir' 'run' em ${NIRI_CONFIG_FILE}..."
        sudo -u "${REAL_USER}" tee -a "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'

// Autostart da interface de usuário iNiR
spawn-at-startup "inir" "run"
EOF
        log_success "Autostart do iNiR adicionado ao ${NIRI_CONFIG_FILE}."
    else
        log_info "Autostart do iNiR já presente em ${NIRI_CONFIG_FILE}."
    fi

    # 2. Injeção de variáveis de renderização segura para VM
    if [[ "${IS_VM:-false}" == true ]]; then
        if ! grep -q 'LIBGL_ALWAYS_SOFTWARE "1"' "${NIRI_CONFIG_FILE}"; then
            log_info "Detectado ambiente VM (IS_VM=true). Injetando parâmetros de renderização por software no Niri..."
            sudo -u "${REAL_USER}" tee -a "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'

// =============================================================================
// Ajustes automáticos para Máquina Virtual (VMware / VirtualBox)
environment {
    LIBGL_ALWAYS_SOFTWARE "1"
    WLR_NO_HARDWARE_CURSORS "1"
}
EOF
            log_success "Flags de VM anexadas dinamicamente ao final de ${NIRI_CONFIG_FILE}."
        else
            log_info "Flags de VM já presentes em ${NIRI_CONFIG_FILE}."
        fi
    fi

    # 3. Assegura layout de teclado ABNT2 (layout "br")
    if [[ "${KEYBOARD_ABNT2:-true}" == true ]]; then
        if ! grep -q 'layout "br"' "${NIRI_CONFIG_FILE}"; then
            log_info "Configurando layout de teclado ABNT2 (br) no Niri..."
            if grep -q 'xkb {' "${NIRI_CONFIG_FILE}"; then
                # Se bloco xkb já existe sem layout br, injeta layout "br" dentro de xkb
                sudo -u "${REAL_USER}" sed -i '/xkb {/a \        layout "br"' "${NIRI_CONFIG_FILE}"
            elif grep -q 'keyboard {' "${NIRI_CONFIG_FILE}"; then
                # Se bloco keyboard já existe sem xkb, injeta xkb com layout br dentro de keyboard
                sudo -u "${REAL_USER}" sed -i '/keyboard {/a \        xkb {\n            layout "br"\n        }' "${NIRI_CONFIG_FILE}"
            else
                # Se não houver bloco de entrada/teclado, anexa bloco input completo
                sudo -u "${REAL_USER}" tee -a "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'

input {
    keyboard {
        xkb {
            layout "br"
        }
    }
}
EOF
            fi
            log_success "Layout ABNT2 (br) configurado em ${NIRI_CONFIG_FILE}."
        else
            log_info "Layout ABNT2 (br) já presente em ${NIRI_CONFIG_FILE}."
        fi
    fi

    # 4. Validação oficial do Niri
    log_info "Validando configuração do Niri para iNiR (niri validate)..."
    if command -v niri >/dev/null 2>&1; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: 'niri validate' confirmou o arquivo de configuração do iNiR."
        else
            log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração do iNiR!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    elif [[ -x "/usr/bin/niri" ]]; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: '/usr/bin/niri validate' confirmou o arquivo do iNiR."
        else
            log_error "[Checklist] Falha crítica: '/usr/bin/niri validate' retornou erro na configuração do iNiR!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    else
        log_warn "[Checklist] Binário 'niri' não encontrado no PATH para executar a validação nativa imediata."
    fi
elif [[ "${SELECTED_INTERFACE}" == "danklinux" ]]; then
    NIRI_CONFIG_DIR="${REAL_HOME}/.config/niri"
    NIRI_CONFIG_FILE="${NIRI_CONFIG_DIR}/config.kdl"

    log_info "Interface selecionada é DankMaterialShell (DMS): ajustando configurações no Niri..."
    sudo -u "${REAL_USER}" mkdir -p "${NIRI_CONFIG_DIR}"

    if [[ ! -f "${NIRI_CONFIG_FILE}" ]]; then
        log_warn "Arquivo ${NIRI_CONFIG_FILE} não encontrado após a instalação do DMS. Criando arquivo base..."
        sudo -u "${REAL_USER}" touch "${NIRI_CONFIG_FILE}"
    fi

    # 1. Injeção de Autostart do DankMaterialShell (DMS)
    if ! grep -q 'spawn-at-startup "dms"' "${NIRI_CONFIG_FILE}"; then
        log_info "Configurando autostart do DankMaterialShell (dms run) no Niri..."
        # Injeta spawn-at-startup "dms" "run" no topo do arquivo de configuração
        sudo -u "${REAL_USER}" sed -i '1i spawn-at-startup "dms" "run"' "${NIRI_CONFIG_FILE}"
        log_success "Autostart do DankMaterialShell configurado com sucesso em ${NIRI_CONFIG_FILE}."
    else
        log_info "Autostart do DankMaterialShell já presente em ${NIRI_CONFIG_FILE}."
    fi

    # 2. Configuração de layout de teclado ABNT2 (br)
    if [[ "${KEYBOARD_ABNT2:-true}" == true ]]; then
        if ! grep -q 'layout "br"' "${NIRI_CONFIG_FILE}"; then
            log_info "Configurando layout de teclado ABNT2 (br) no Niri (DMS)..."
            if grep -q 'xkb {' "${NIRI_CONFIG_FILE}"; then
                sudo -u "${REAL_USER}" sed -i '/xkb {/a \        layout "br"' "${NIRI_CONFIG_FILE}"
            elif grep -q 'keyboard {' "${NIRI_CONFIG_FILE}"; then
                sudo -u "${REAL_USER}" sed -i '/keyboard {/a \        xkb {\n            layout "br"\n        }' "${NIRI_CONFIG_FILE}"
            else
                sudo -u "${REAL_USER}" tee -a "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'

input {
    keyboard {
        xkb {
            layout "br"
        }
    }
}
EOF
            fi
            log_success "Layout ABNT2 (br) configurado em ${NIRI_CONFIG_FILE}."
        else
            log_info "Layout ABNT2 (br) já presente em ${NIRI_CONFIG_FILE}."
        fi
    fi

    # 3. Injeção de variáveis de renderização segura para VM
    if [[ "${IS_VM:-false}" == true ]]; then
        log_info "Detectado ambiente VM (IS_VM=true). Assegurando flags de renderização por software no Niri..."
        if grep -q 'environment {' "${NIRI_CONFIG_FILE}"; then
            if ! grep -q 'LIBGL_ALWAYS_SOFTWARE' "${NIRI_CONFIG_FILE}"; then
                sudo -u "${REAL_USER}" sed -i '/environment {/a \    LIBGL_ALWAYS_SOFTWARE "1"\n    WLR_NO_HARDWARE_CURSORS "1"' "${NIRI_CONFIG_FILE}"
            fi
        else
            sudo -u "${REAL_USER}" tee -a "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'

// =============================================================================
// Ajustes automáticos para Máquina Virtual (VMware / VirtualBox)
environment {
    LIBGL_ALWAYS_SOFTWARE "1"
    WLR_NO_HARDWARE_CURSORS "1"
}
EOF
        fi
        log_success "Flags de VM asseguradas em ${NIRI_CONFIG_FILE}."
    fi

    # 4. Garantir permissões de posse antes da validação
    ensure_user_ownership "${REAL_HOME}/.config"

    # 5. Validação oficial do Niri
    log_info "Validando configuração do Niri para DankMaterialShell (niri validate)..."
    if command -v niri >/dev/null 2>&1; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: 'niri validate' confirmou o arquivo de configuração do DMS."
        else
            log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração do DMS!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    elif [[ -x "/usr/bin/niri" ]]; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: '/usr/bin/niri validate' confirmou o arquivo do DMS."
        else
            log_error "[Checklist] Falha crítica: '/usr/bin/niri validate' retornou erro na configuração do DMS!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    else
        log_warn "[Checklist] Binário 'niri' não encontrado no PATH para executar a validação nativa imediata."
    fi
fi

# Garante permissões estritas para o usuário real
ensure_user_ownership "${REAL_HOME}/.config"
ensure_user_ownership "${REAL_HOME}/.local"
log_success "Permissões de ${REAL_HOME}/.config e ${REAL_HOME}/.local garantidas para ${REAL_USER}."

# 3. Criação das Pastas Padrões do Usuário (Documentos, Downloads, etc.)
log_info "Inicializando diretórios padrão de usuário XDG..."
sudo -u "${REAL_USER}" xdg-user-dirs-update || true
log_success "Pastas padrão XDG criadas."

# 4. Compilação do Driver NVIDIA (Apenas para Máquina Física)
if [[ "${IS_VM:-false}" == false ]] && [[ "${INSTALL_NVIDIA:-false}" == true ]]; then
    log_info "Compilando módulo do kernel NVIDIA via akmods..."
    sudo akmods --force || log_warn "Aviso na execução do akmods. Verifique o status do módulo do kernel."
    log_success "Compilação do módulo NVIDIA concluída."
fi

# 5. Definição do Alvo Gráfico e Ativação do Display Manager no Systemd
if [[ "${SELECTED_INTERFACE:-}" =~ ^(danklinux|noctalia)$ || "${SELECTED_SHELL:-}" =~ ^(danklinux|noctalia)$ ]]; then
    log_info "Configurando inicialização gráfica padrão (Greetd)..."
    sudo systemctl disable gdm lightdm sddm 2>/dev/null || true
    sudo systemctl enable greetd.service
    sudo systemctl set-default graphical.target
    log_success "Target gráfico e greetd.service definidos como padrão."

    log_info "Assegurando integridade do PAM GNOME Keyring em /etc/pam.d/greetd..."
    if [[ -f "${SYSTEM_DIR}/pam_greetd.template" ]]; then
        sudo cp "${SYSTEM_DIR}/pam_greetd.template" /etc/pam.d/greetd
        sudo chmod 644 /etc/pam.d/greetd
        sudo chown root:root /etc/pam.d/greetd
    fi
else
    log_info "Configurando inicialização gráfica padrão (SDDM)..."
    sudo systemctl disable gdm lightdm greetd 2>/dev/null || true
    sudo systemctl enable sddm.service
    sudo systemctl set-default graphical.target
    log_success "Target gráfico e sddm.service definidos como padrão."

    log_info "Assegurando integridade do PAM GNOME Keyring em /etc/pam.d/sddm..."
    if [[ -f "${SYSTEM_DIR}/pam_sddm.template" ]]; then
        if ! grep -qF "pam_gnome_keyring.so" /etc/pam.d/sddm 2>/dev/null; then
            sudo cp "${SYSTEM_DIR}/pam_sddm.template" /etc/pam.d/sddm
            sudo chmod 644 /etc/pam.d/sddm
            sudo chown root:root /etc/pam.d/sddm
        fi
    fi
fi

# 6. Checklist Interno de Testes e Validação
echo ""
log_info "Iniciando checagens internas de integridade do sistema..."

# Teste 1: Serviço de Display Manager
if [[ "${SELECTED_INTERFACE:-}" =~ ^(danklinux|noctalia)$ || "${SELECTED_SHELL:-}" =~ ^(danklinux|noctalia)$ ]]; then
    if systemctl is-enabled greetd.service >/dev/null 2>&1; then
        log_success "[Checklist] greetd.service está devidamente habilitado no systemd."
    else
        log_warn "[Checklist] greetd.service não reportou status enabled via systemctl is-enabled."
    fi
elif [[ "${SELECTED_INTERFACE:-}" == "inir" || "${SELECTED_SHELL:-}" == "inir" ]]; then
    if systemctl is-enabled sddm.service >/dev/null 2>&1; then
        log_success "[Checklist] sddm.service está devidamente habilitado no systemd."
    else
        log_warn "[Checklist] sddm.service não reportou status enabled via systemctl is-enabled."
    fi
fi

# Teste 2: PAM do Display Manager (Checklist Final Rigoroso)
if [[ "${SELECTED_INTERFACE:-}" =~ ^(danklinux|noctalia)$ || "${SELECTED_SHELL:-}" == "noctalia" ]]; then
    if grep -qF "pam_gnome_keyring.so" /etc/pam.d/greetd; then
        log_ok "[Checklist] Integração com pam_gnome_keyring.so confirmada em /etc/pam.d/greetd."
    else
        log_error "[Checklist] Falha: Integração com pam_gnome_keyring.so ausente em /etc/pam.d/greetd!"
        exit 1
    fi
elif [[ "${SELECTED_INTERFACE:-}" == "inir" || "${SELECTED_SHELL:-}" == "inir" ]]; then
    if grep -qF "pam_gnome_keyring.so" /etc/pam.d/sddm; then
        log_ok "[Checklist] Integração com pam_gnome_keyring.so confirmada em /etc/pam.d/sddm."
    else
        log_error "[Checklist] Falha: Integração com pam_gnome_keyring.so ausente em /etc/pam.d/sddm!"
        exit 1
    fi
fi

# Teste 3: Validação do Compositor Selecionado
if [[ "${SELECTED_COMPOSITOR}" == "niri" ]]; then
    if [[ -f "${NIRI_CONFIG_FILE}" ]]; then
        log_success "[Checklist] Arquivo ${NIRI_CONFIG_FILE} verificado no disco."
    else
        log_error "[Checklist] Falha crítica: ${NIRI_CONFIG_FILE} não existe!"
        exit 1
    fi

    log_info "Executando validador oficial do Niri (niri validate)..."
    if command -v niri >/dev/null 2>&1; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: 'niri validate' confirmou o arquivo de configuração."
        else
            log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    elif [[ -x "/usr/bin/niri" ]]; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: '/usr/bin/niri validate' confirmou o arquivo."
        else
            log_error "[Checklist] Falha crítica: '/usr/bin/niri validate' retornou erro na configuração!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    else
        log_warn "[Checklist] Binário 'niri' não encontrado no PATH para executar a validação nativa imediata."
    fi

    CONFIG_OWNER="$(stat -c '%U' "${NIRI_CONFIG_FILE}" 2>/dev/null || echo 'desconhecido')"
    if [[ "$CONFIG_OWNER" == "$REAL_USER" ]]; then
        log_success "[Checklist] Propriedade de ${NIRI_CONFIG_FILE} pertence corretamente ao usuário '${REAL_USER}'."
    else
        log_warn "[Checklist] Proprietário do arquivo é '${CONFIG_OWNER}'. Corrigindo permissão..."
        ensure_user_ownership "${NIRI_CONFIG_DIR}"
    fi

elif [[ "${SELECTED_COMPOSITOR}" == "umbriel" ]]; then
    if [[ -f "${UMB_CONFIG_FILE}" ]]; then
        log_success "[Checklist] Arquivo ${UMB_CONFIG_FILE} verificado no disco."
    else
        log_error "[Checklist] Falha crítica: ${UMB_CONFIG_FILE} não existe!"
        exit 1
    fi

    log_info "Executando validador oficial do Umbriel (umbriel config validate)..."
    if command -v umbriel >/dev/null 2>&1; then
        if UMB_VAL_OUTPUT="$(sudo -u "${REAL_USER}" umbriel config validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: 'umbriel config validate' confirmou o arquivo de configuração."
        else
            log_warn "[Checklist] Aviso na validação do Umbriel: ${UMB_VAL_OUTPUT}"
        fi
    elif [[ -x "/usr/bin/umbriel" ]]; then
        if UMB_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/umbriel config validate 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: '/usr/bin/umbriel config validate' confirmou o arquivo."
        else
            log_warn "[Checklist] Aviso na validação do Umbriel: ${UMB_VAL_OUTPUT}"
        fi
    else
        log_warn "[Checklist] Binário 'umbriel' não encontrado no PATH para executar a validação nativa imediata."
    fi

    CONFIG_OWNER="$(stat -c '%U' "${UMB_CONFIG_FILE}" 2>/dev/null || echo 'desconhecido')"
    if [[ "$CONFIG_OWNER" == "$REAL_USER" ]]; then
        log_success "[Checklist] Propriedade de ${UMB_CONFIG_FILE} pertence corretamente ao usuário '${REAL_USER}'."
    else
        log_warn "[Checklist] Proprietário do arquivo é '${CONFIG_OWNER}'. Corrigindo permissão..."
        ensure_user_ownership "${UMB_CONFIG_DIR}"
    fi
fi

# Teste 4: Validação de ausência de NVIDIA em VM
if [[ "${IS_VM:-false}" == true ]]; then
    if rpm -q akmod-nvidia >/dev/null 2>&1; then
        log_error "[Checklist] Inconsistência: akmod-nvidia instalado em ambiente de Máquina Virtual!"
    else
        log_success "[Checklist] Confirmado: drivers proprietários NVIDIA não foram instalados na VM."
    fi
fi

# Teste 5: Validação da instalação do pacote gnome-keyring-pam
if rpm -q gnome-keyring-pam >/dev/null 2>&1; then
    log_success "[Checklist] Pacote 'gnome-keyring-pam' confirmado instalado."
else
    log_error "[Checklist] Falha crítica: Pacote 'gnome-keyring-pam' não está instalado!"
    exit 1
fi

# Teste 6: Validação do ponteiro padrão do chaveiro (${KEYRINGS_DIR}/default)
if [[ -f "${KEYRINGS_DIR}/default" ]] && [[ "$(cat "${KEYRINGS_DIR}/default" 2>/dev/null)" == "login" ]]; then
    DEFAULT_PERM="$(stat -c '%a' "${KEYRINGS_DIR}/default" 2>/dev/null || echo '')"
    if [[ "$DEFAULT_PERM" == "600" ]]; then
        log_success "[Checklist] Arquivo ${KEYRINGS_DIR}/default verificado (conteúdo 'login' e permissão 600)."
    else
        log_warn "[Checklist] Permissão de ${KEYRINGS_DIR}/default era '${DEFAULT_PERM}'. Corrigindo para 600..."
        sudo chmod 600 "${KEYRINGS_DIR}/default"
        log_success "[Checklist] Permissão de ${KEYRINGS_DIR}/default ajustada para 600."
    fi
else
    log_error "[Checklist] Falha crítica: ${KEYRINGS_DIR}/default não existe ou não contém exatamente 'login'!"
    exit 1
fi

# Teste 7: Validação de permissão e propriedade da pasta keyrings
KEYRINGS_PERM="$(stat -c '%a' "${KEYRINGS_DIR}" 2>/dev/null || echo '')"
KEYRINGS_OWNER="$(stat -c '%U' "${KEYRINGS_DIR}" 2>/dev/null || echo '')"
if [[ "$KEYRINGS_PERM" == "700" ]] && [[ "$KEYRINGS_OWNER" == "$REAL_USER" ]]; then
    log_success "[Checklist] Pasta ${KEYRINGS_DIR} confirmada com permissão 700 pertencente a ${REAL_USER}."
else
    log_warn "[Checklist] Permissão/proprietário da pasta ${KEYRINGS_DIR} (${KEYRINGS_PERM}, ${KEYRINGS_OWNER}). Corrigindo..."
    sudo chmod 700 "${KEYRINGS_DIR}"
    sudo chown -R "${REAL_USER}:${REAL_USER}" "${KEYRINGS_DIR}"
    log_success "[Checklist] Pasta ${KEYRINGS_DIR} corrigida para 700 e propriedade de ${REAL_USER}."
fi

# Teste 8: Validação do runtime Deno (exclusivo do caminho iNiR)
if [[ "${SELECTED_INTERFACE}" == "inir" ]]; then
    if command -v deno >/dev/null 2>&1; then
        log_success "[Checklist] Runtime Deno confirmado: $(deno --version | head -n1)."
    else
        log_error "[Checklist] Falha crítica: Deno não encontrado no PATH para a interface iNiR!"
        exit 1
    fi
fi

echo ""
log_success "Módulo 07 (Pós-Instalação) concluído com 100% de sucesso!"
