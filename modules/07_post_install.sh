#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/07_post_install.sh
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
SELECTED_SHELL="${SELECTED_SHELL:-inir}"

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
if [[ "${SELECTED_COMPOSITOR}" == "niri" ]]; then
    NIRI_CONFIG_DIR="${REAL_HOME}/.config/niri"
    NIRI_CONFIG_FILE="${NIRI_CONFIG_DIR}/config.kdl"
    SYSTEM_NIRI_CONF="/usr/share/doc/niri/config.kdl"

    log_info "Configurando ambiente do Niri em ${NIRI_CONFIG_FILE}..."
    sudo -u "${REAL_USER}" mkdir -p "${NIRI_CONFIG_DIR}"

    # Backup do config se já existir
    if [[ -f "${NIRI_CONFIG_FILE}" ]]; then
        backup_file "${NIRI_CONFIG_FILE}" false
    fi

    # Copia a configuração padrão do Niri se o arquivo do usuário ainda não existir
    if [[ ! -f "${NIRI_CONFIG_FILE}" ]]; then
        if [[ -f "${SYSTEM_NIRI_CONF}" ]]; then
            sudo -u "${REAL_USER}" cp "${SYSTEM_NIRI_CONF}" "${NIRI_CONFIG_FILE}"
            log_info "Configuração padrão copiada de ${SYSTEM_NIRI_CONF}."
        elif [[ -f "/usr/share/doc/niri-git/config.kdl" ]]; then
            sudo -u "${REAL_USER}" cp "/usr/share/doc/niri-git/config.kdl" "${NIRI_CONFIG_FILE}"
            log_info "Configuração padrão copiada de /usr/share/doc/niri-git/config.kdl."
        elif [[ -f "/etc/niri/config.kdl" ]]; then
            sudo -u "${REAL_USER}" cp "/etc/niri/config.kdl" "${NIRI_CONFIG_FILE}"
            log_info "Configuração padrão copiada de /etc/niri/config.kdl."
        else
            log_info "Criando arquivo base inicial config.kdl para Niri..."
            sudo -u "${REAL_USER}" tee "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'
// Niri Base Configuration
input {
    keyboard {
        xkb {
        }
    }
}
EOF
        fi
    fi

    # Injeta autostart da shell selecionada e flags de teclado/VM no config.kdl
    log_info "Ajustando autostart de '${SELECTED_SHELL}' e parâmetros no config.kdl do Niri..."

    python3 - "$NIRI_CONFIG_FILE" "${IS_VM:-false}" "${KEYBOARD_ABNT2:-true}" "${SELECTED_SHELL}" <<'PYEOF'
import os
import re
import sys

config_file = sys.argv[1]
is_vm = (sys.argv[2].lower() == "true")
is_abnt2 = (sys.argv[3].lower() == "true")
shell_type = sys.argv[4].lower()

content = ""
if os.path.exists(config_file):
    with open(config_file, "r", encoding="utf-8") as f:
        content = f.read()

# Define linha de autostart conforme a shell
if shell_type == "inir":
    spawn_cmd = 'spawn-at-startup "inir" "run"'
else:
    if is_vm:
        spawn_cmd = 'spawn-at-startup "env" "LIBGL_ALWAYS_SOFTWARE=1" "noctalia"'
    else:
        spawn_cmd = 'spawn-at-startup "noctalia"'

if spawn_cmd not in content:
    content = f'{spawn_cmd}\n' + content

# Configura layout de teclado ABNT2 no bloco input/keyboard se solicitado
if is_abnt2:
    if 'layout "br"' not in content:
        if re.search(r'xkb\s*\{', content):
            content = re.sub(
                r'(xkb\s*\{)',
                r'\1\n        layout "br";',
                content,
                count=1
            )
        elif re.search(r'keyboard\s*\{', content):
            content = re.sub(
                r'(keyboard\s*\{)',
                r'\1\n        xkb {\n            layout "br";\n        }',
                content,
                count=1
            )
        elif re.search(r'input\s*\{', content):
            content = re.sub(
                r'(input\s*\{)',
                r'\1\n    keyboard {\n        xkb {\n            layout "br";\n        }\n    }',
                content,
                count=1
            )
        else:
            content += '\ninput {\n    keyboard {\n        xkb {\n            layout "br";\n        }\n    }\n}\n'

# Flags para ambiente VM (software rendering / cursores)
if is_vm:
    vm_comment = "// Configurações para VM"
    if vm_comment not in content:
        content += """
// Configurações para VM
environment {
    LIBGL_ALWAYS_SOFTWARE "1"
    WLR_NO_HARDWARE_CURSORS "1"
}
"""

with open(config_file, "w", encoding="utf-8") as f:
    f.write(content)

print("[OK] Arquivo config.kdl do Niri ajustado com sucesso.")
PYEOF

elif [[ "${SELECTED_COMPOSITOR}" == "umbriel" ]]; then
    UMB_CONFIG_DIR="${REAL_HOME}/.config/umbriel"
    UMB_CONFIG_FILE="${UMB_CONFIG_DIR}/config.toml"
    SYSTEM_UMB_CONF="/usr/share/umbriel/config.toml"

    log_info "Configurando ambiente do Umbriel em ${UMB_CONFIG_FILE}..."
    sudo -u "${REAL_USER}" mkdir -p "${UMB_CONFIG_DIR}"

    if [[ -f "${UMB_CONFIG_FILE}" ]]; then
        backup_file "${UMB_CONFIG_FILE}" false
    fi

    # Copia modelo de configuração caso ausente
    if [[ ! -f "${UMB_CONFIG_FILE}" ]]; then
        if [[ -f "${SYSTEM_UMB_CONF}" ]]; then
            sudo -u "${REAL_USER}" cp "${SYSTEM_UMB_CONF}" "${UMB_CONFIG_FILE}"
            log_info "Configuração padrão copiada de ${SYSTEM_UMB_CONF}."
        elif [[ -f "/etc/umbriel/config.toml" ]]; then
            sudo -u "${REAL_USER}" cp "/etc/umbriel/config.toml" "${UMB_CONFIG_FILE}"
            log_info "Configuração padrão copiada de /etc/umbriel/config.toml."
        else
            log_info "Criando modelo base inicial config.toml para Umbriel..."
            sudo -u "${REAL_USER}" tee "${UMB_CONFIG_FILE}" >/dev/null <<'EOF'
[general]
autostart = ["noctalia"]
show_cheatsheet = false

[input.keyboard]

[input.cursor]

[keybinds]
"Mod+Return" = "spawn:kitty"
"Mod" = "spawn:noctalia msg panel-toggle launcher"
"Mod+Q" = "window-close"
"Mod+Escape" = "quit"
EOF
        fi
    fi

    log_info "Ajustando autostart, layout ABNT2, environment e parâmetros no config.toml do Umbriel..."
    python3 - "$UMB_CONFIG_FILE" "${IS_VM:-false}" "${KEYBOARD_ABNT2:-true}" <<'PYEOF'
import os
import re
import sys

config_file = sys.argv[1]
is_vm = (sys.argv[2].lower() == "true")
is_abnt2 = (sys.argv[3].lower() == "true")

content = ""
if os.path.exists(config_file):
    with open(config_file, "r", encoding="utf-8") as f:
        content = f.read()

# 1. Garante cabeçalho [general] descomentado
content = re.sub(r'^[ \t]*#[ \t]*\[general\][ \t]*$', '[general]', content, flags=re.MULTILINE)

# Garante a existência de [general] se não existir
if "[general]" not in content:
    content = "[general]\n\n" + content

# 2. Descomenta qualquer 'autostart = ...' sob [general] ou linha comentada
content = re.sub(r'^[ \t]*#[ \t]*(autostart\s*=)', r'\1', content, flags=re.MULTILINE)

# 3. Define autostart estritamente como ["noctalia"]
if re.search(r'\[general\][^\[]*?autostart\s*=', content):
    content = re.sub(
        r'(\[general\][^\[]*?autostart\s*=\s*)(?:\[[^\]]*\]|"[^"]*"|[^\n]+)',
        r'\1["noctalia"]',
        content,
        count=1
    )
else:
    content = re.sub(
        r'(\[general\])',
        r'\1\nautostart = ["noctalia"]',
        content,
        count=1
    )

# 4. Desativa a modal de cheatsheet sob [general] para evitar bloqueio de foco no boot
# Remove variantes comentadas ou ativas anteriores de show_cheatsheet
content = re.sub(r'^[ \t]*#?[ \t]*show_cheatsheet\s*=.*$', '', content, flags=re.MULTILINE)
# Adiciona show_cheatsheet = false logo sob [general]
content = re.sub(
    r'(\[general\])',
    r'\1\nshow_cheatsheet = false',
    content,
    count=1
)

# 5. Configura layout de teclado ABNT2 sob [input.keyboard] se solicitado
if is_abnt2:
    if 'layout = "br"' not in content:
        if "[input.keyboard]" in content:
            content = re.sub(
                r'(\[input\.keyboard\])',
                r'\1\nlayout = "br"',
                content,
                count=1
            )
        elif "[input]" in content:
            content = re.sub(
                r'(\[input\])',
                r'\1\n[input.keyboard]\nlayout = "br"',
                content,
                count=1
            )
        else:
            content += '\n[input.keyboard]\nlayout = "br"\n'

# 6. Configurações para Máquina Virtual (hardware_cursor e seção nativa [environment])
if is_vm:
    # Cursor por software sob [input.cursor]
    if "hardware_cursor = false" not in content and "hardware_cursor=false" not in content:
        if "[input.cursor]" in content:
            content = re.sub(
                r'(\[input\.cursor\])',
                r'\1\nhardware_cursor = false',
                content,
                count=1
            )
        elif "[cursor]" in content:
            content = re.sub(
                r'(\[cursor\])',
                r'\1\nhardware_cursor = false',
                content,
                count=1
            )
        elif "[input]" in content:
            content = re.sub(
                r'(\[input\])',
                r'\1\n[input.cursor]\nhardware_cursor = false',
                content,
                count=1
            )
        else:
            content += '\n[input.cursor]\nhardware_cursor = false\n'

    # Seção nativa [environment] com flags de renderização de VM
    if "[environment]" in content:
        if "LIBGL_ALWAYS_SOFTWARE" not in content:
            content = re.sub(
                r'(\[environment\])',
                r'\1\nLIBGL_ALWAYS_SOFTWARE = "1"',
                content,
                count=1
            )
        if "WLR_NO_HARDWARE_CURSORS" not in content:
            content = re.sub(
                r'(\[environment\])',
                r'\1\nWLR_NO_HARDWARE_CURSORS = "1"',
                content,
                count=1
            )
    else:
        content += '\n[environment]\nLIBGL_ALWAYS_SOFTWARE = "1"\nWLR_NO_HARDWARE_CURSORS = "1"\n'

# 7. Preservação / Garantia de Atalhos Nativos ([keybinds])
# Se por algum motivo o arquivo de configuração não possuir bloco [keybinds] ou faltar atalhos essenciais:
if "[keybinds]" not in content:
    content += '\n[keybinds]\n"Mod+Return" = "spawn:kitty"\n"Mod" = "spawn:noctalia msg panel-toggle launcher"\n'
else:
    if '"Mod+Return"' not in content:
        content = re.sub(
            r'(\[keybinds\])',
            r'\1\n"Mod+Return" = "spawn:kitty"',
            content,
            count=1
        )
    if '"Mod"' not in content and "'Mod'" not in content:
        content = re.sub(
            r'(\[keybinds\])',
            r'\1\n"Mod" = "spawn:noctalia msg panel-toggle launcher"',
            content,
            count=1
        )

with open(config_file, "w", encoding="utf-8") as f:
    f.write(content)

print("[OK] Arquivo config.toml do Umbriel ajustado com sucesso.")
PYEOF

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
if [[ "${SELECTED_SHELL}" == "noctalia" ]]; then
    log_info "Configurando inicialização gráfica padrão (Greetd com Noctalia Greeter)..."
    sudo systemctl disable gdm lightdm sddm 2>/dev/null || true
    sudo systemctl enable --force greetd.service
    sudo systemctl set-default graphical.target
    log_success "Target gráfico e greetd.service definidos como padrão."
else
    log_info "Configurando inicialização gráfica padrão (SDDM)..."
    sudo systemctl disable gdm lightdm greetd 2>/dev/null || true
    sudo systemctl enable --force sddm.service
    sudo systemctl set-default graphical.target
    log_success "Target gráfico e sddm.service definidos como padrão."
fi

# 6. Checklist Interno de Testes e Validação
echo ""
log_info "Iniciando checagens internas de integridade do sistema..."

# Teste 1: Serviço de Display Manager
if [[ "${SELECTED_SHELL}" == "noctalia" ]]; then
    if systemctl is-enabled greetd.service >/dev/null 2>&1; then
        log_success "[Checklist] greetd.service está devidamente habilitado no systemd."
    else
        log_warn "[Checklist] greetd.service não reportou status enabled via systemctl is-enabled."
    fi

    # Teste 2: PAM do Greetd
    if [[ -f "/etc/pam.d/greetd" ]] && grep -q "pam_gnome_keyring.so" /etc/pam.d/greetd; then
        log_success "[Checklist] /etc/pam.d/greetd contém integração ativa com pam_gnome_keyring.so."
    else
        log_error "[Checklist] Falha: Integração com pam_gnome_keyring.so ausente em /etc/pam.d/greetd!"
        exit 1
    fi
else
    if systemctl is-enabled sddm.service >/dev/null 2>&1; then
        log_success "[Checklist] sddm.service está devidamente habilitado no systemd."
    else
        log_warn "[Checklist] sddm.service não reportou status enabled via systemctl is-enabled."
    fi

    # Teste 2: PAM do SDDM
    if [[ -f "/etc/pam.d/sddm" ]] && grep -q "pam_gnome_keyring.so" /etc/pam.d/sddm; then
        log_success "[Checklist] /etc/pam.d/sddm contém integração ativa com pam_gnome_keyring.so."
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

# Teste 5: Validação de ausência de NVIDIA em VM
if [[ "${IS_VM:-false}" == true ]]; then
    if rpm -q akmod-nvidia >/dev/null 2>&1; then
        log_error "[Checklist] Inconsistência: akmod-nvidia instalado em ambiente de Máquina Virtual!"
    else
        log_success "[Checklist] Confirmado: drivers proprietários NVIDIA não foram instalados na VM."
    fi
fi

# Teste 6: Validação da instalação do pacote gnome-keyring-pam
if rpm -q gnome-keyring-pam >/dev/null 2>&1; then
    log_success "[Checklist] Pacote 'gnome-keyring-pam' confirmado instalado."
else
    log_error "[Checklist] Falha crítica: Pacote 'gnome-keyring-pam' não está instalado!"
    exit 1
fi

# Teste 7: Validação do ponteiro padrão do chaveiro (${KEYRINGS_DIR}/default)
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

# Teste 8: Validação de permissão e propriedade da pasta keyrings
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

echo ""
log_success "Módulo 07 (Pós-Instalação) concluído com 100% de sucesso!"
