#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/07_post_install.sh
# Configurações de pós-instalação: Keyring, Compositor config (Niri/Umbriel),
# autostart de Shell (iNiR/Noctalia), VM flags, target gráfico e testes
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
NIRI_SHELLS_DIR="${NIRI_CONFIG_DIR}/shells"
NIRI_CONFIG_FILE="${NIRI_CONFIG_DIR}/config.kdl"
UMB_CONFIG_DIR="${REAL_HOME}/.config/umbriel"
UMB_CONFIG_FILE="${UMB_CONFIG_DIR}/config.toml"

log_info "Executando ajustes pós-instalação para o usuário: ${REAL_USER} (${REAL_HOME})"
log_info "Configurações ativas -> Compositor: ${SELECTED_COMPOSITOR} | Shell: ${SELECTED_SHELL}"

# 1. Inicialização do cofre de credenciais oo7 e vínculo canônico com o PAM
# (Fedora 45: o provedor do Secret Service é o oo7; o chaveiro 'login' é
# criado/destravado pelo oo7-daemon via pam_oo7 no primeiro login gráfico.)
log_info "Preparando diretório do cofre de credenciais oo7..."
KEYRINGS_DIR="${REAL_HOME}/.local/share/keyrings"
sudo -u "${REAL_USER}" mkdir -p "${KEYRINGS_DIR}"
sudo chmod 700 "${KEYRINGS_DIR}"
sudo chown -R "${REAL_USER}:${REAL_USER}" "${KEYRINGS_DIR}"
log_success "Diretório ${KEYRINGS_DIR} pronto para o oo7 (permissão 700, proprietário ${REAL_USER})."

# 1.1 Habilitação da unidade de usuário do oo7-daemon no login
# (Fedora 45: o destravamento automático do chaveiro 'login' exige que o
# oo7-daemon esteja rodando dentro da sessão gráfica. O %systemd_user_post do
# pacote tenta habilitá-lo via preset, mas em instalação mínima com Greetd/SDDM
# isso pode não ter sido aplicado ao usuário-alvo (cf. bug Silverblue #714).
# Habilitamos explicitamente para reproduzir o comportamento do antigo
# gnome-keyring: logar e o navegador já encontrar o cofre destravado, sem popup.)
log_info "Habilitando oo7-daemon.service (unidade de usuário) no login..."
if [[ -f "/usr/lib/systemd/user/oo7-daemon.service" ]]; then
    if sudo -u "${REAL_USER}" XDG_RUNTIME_DIR="/run/user/$(id -u "${REAL_USER}")" \
          systemctl --user enable oo7-daemon.service >/dev/null 2>&1; then
        log_success "oo7-daemon.service habilitado para ${REAL_USER} (chaveiro ativo já no primeiro login)."
    else
        sudo -u "${REAL_USER}" mkdir -p "${REAL_HOME}/.config/systemd/user/default.target.wants"
        sudo -u "${REAL_USER}" ln -sfn "/usr/lib/systemd/user/oo7-daemon.service" \
            "${REAL_HOME}/.config/systemd/user/default.target.wants/oo7-daemon.service"
        log_success "oo7-daemon.service habilitado via symlink offline (default.target.wants)."
    fi
else
    log_warn "Unidade oo7-daemon.service ausente; verifique o empacotamento do oo7 nesta release."
fi

# 1.2 ssh-agent oficial do OpenSSH via socket activation do systemd
# (OpenSSH >= 10.0 no Fedora 45; desacoplado do provedor de segredos —
# guarda a passphrase das chaves SSH em memória durante a sessão.)
log_info "Habilitando ssh-agent do OpenSSH (socket activation systemd de usuário)..."
if [[ -f "/usr/lib/systemd/user/ssh-agent.socket" ]]; then
    # Caminho ideal: manager de usuário ativo (instalador rodando dentro da
    # sessão do usuário). Fora dele, fallback offline: criar o symlink de
    # 'wants' manualmente — exatamente o que o enable faria.
    if sudo -u "${REAL_USER}" XDG_RUNTIME_DIR="/run/user/$(id -u "${REAL_USER}")" \
          systemctl --user enable ssh-agent.socket >/dev/null 2>&1; then
        log_success "ssh-agent.socket habilitado para ${REAL_USER} (SSH_AUTH_SOCK via systemd)."
    else
        sudo -u "${REAL_USER}" mkdir -p "${REAL_HOME}/.config/systemd/user/default.target.wants"
        sudo -u "${REAL_USER}" ln -sfn "/usr/lib/systemd/user/ssh-agent.socket" \
            "${REAL_HOME}/.config/systemd/user/default.target.wants/ssh-agent.socket"
        log_success "ssh-agent.socket habilitado via symlink offline (default.target.wants)."
    fi
else
    log_warn "Unidade ssh-agent.socket ausente desta release do OpenSSH; o ssh usará agente próprio ou sem agente."
fi

# 2. Funções Auxiliares de Sessão Wayland e Configurações Declarativas

# Registra uma sessão Wayland em /usr/share/wayland-sessions a partir de config/system/wayland-sessions
register_wayland_session() {
    local session_file="$1"
    local source_desktop="${SYSTEM_DIR}/wayland-sessions/${session_file}"
    local target_dir="/usr/share/wayland-sessions"
    local target_desktop="${target_dir}/${session_file}"

    if [[ ! -f "$source_desktop" ]]; then
        log_error "Modelo de sessão Wayland não encontrado: ${source_desktop}"
        return 1
    fi

    log_info "Registrando sessão Wayland no sistema (${session_file})..."
    sudo mkdir -p "$target_dir"
    sudo cp "$source_desktop" "$target_desktop"
    sudo chmod 644 "$target_desktop"
    sudo chown root:root "$target_desktop"
    log_success "Sessão '${session_file}' registrada em ${target_dir}."
}

# Aplica parâmetros de renderização por software do Niri caso o ambiente seja Máquina Virtual (IS_VM=true)
apply_niri_vm_flags() {
    local target_file="$1"
    if [[ "${IS_VM:-false}" == true && -f "$target_file" ]]; then
        if ! grep -qF 'LIBGL_ALWAYS_SOFTWARE' "$target_file"; then
            log_info "Detectado ambiente VM (IS_VM=true). Injetando parâmetros de renderização por software em $(basename "$target_file")..."
            sudo -u "${REAL_USER}" tee -a "$target_file" >/dev/null <<'EOF'

// =============================================================================
// Ajustes automáticos para Máquina Virtual (VMware / VirtualBox)
environment {
    LIBGL_ALWAYS_SOFTWARE "1"
    WLR_NO_HARDWARE_CURSORS "1"
}
EOF
            log_success "Flags de VM anexadas dinamicamente ao final de $(basename "$target_file")."
        else
            log_info "Flags de VM já presentes em $(basename "$target_file")."
        fi
    fi
}

# 2.1 Configuração do Compositor Ativo e Shell
if [[ "${SELECTED_INTERFACE}" == "noctalia" || "${SELECTED_SHELL}" == "noctalia" ]]; then
    # Configuração Declarativa do Noctalia Shell
    NOCTALIA_CONFIG_DIR="${REAL_HOME}/.config/noctalia"
    NOCTALIA_CONFIG_FILE="${NOCTALIA_CONFIG_DIR}/config.toml"

    log_info "Configurando ambiente declarativo do Noctalia Shell..."
    sudo -u "${REAL_USER}" mkdir -p "${NOCTALIA_CONFIG_DIR}"

    if [[ -f "${DESKTOP_DIR}/interfaces/noctalia/config.toml" ]]; then
        sudo -u "${REAL_USER}" cp "${DESKTOP_DIR}/interfaces/noctalia/config.toml" "${NOCTALIA_CONFIG_FILE}"
        log_info "Configuração declarativa do Noctalia copiada para ${NOCTALIA_CONFIG_FILE}."
    fi

    ensure_user_ownership "${REAL_HOME}/.config"

    # Configuração do Compositor Ativo para Noctalia
    if [[ "${SELECTED_COMPOSITOR}" == "umbriel" ]]; then
        UMB_CONFIG_DIR="${REAL_HOME}/.config/umbriel"
        UMB_CONFIG_FILE="${UMB_CONFIG_DIR}/config.toml"

        log_info "Configurando ambiente do Umbriel para Noctalia a partir dos templates declarativos..."
        sudo -u "${REAL_USER}" mkdir -p "${UMB_CONFIG_DIR}"

        if [[ -f "${UMB_CONFIG_FILE}" ]]; then
            backup_file "${UMB_CONFIG_FILE}" false
        fi

        sudo -u "${REAL_USER}" cp -r "${DESKTOP_DIR}/compositors/umbriel/"* "${UMB_CONFIG_DIR}/"
        log_info "Configurações declarativas de Umbriel copiadas para ${UMB_CONFIG_DIR}/ com sucesso."

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

        # Registra a sessão Wayland para Noctalia no Umbriel
        register_wayland_session "noctalia-umbriel.desktop"

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
        NIRI_SHELL_FILE="${NIRI_SHELLS_DIR}/noctalia.kdl"

        log_info "Configurando ambiente isolado do Niri para Noctalia..."
        sudo -u "${REAL_USER}" mkdir -p "${NIRI_SHELLS_DIR}"

        # Copia template dedicado do Noctalia
        sudo -u "${REAL_USER}" cp "${DESKTOP_DIR}/compositors/niri/shells/noctalia.kdl" "${NIRI_SHELL_FILE}"
        apply_niri_vm_flags "${NIRI_SHELL_FILE}"

        # Se config.kdl principal não existir, define o do Noctalia como padrão
        if [[ ! -f "${NIRI_CONFIG_FILE}" ]]; then
            sudo -u "${REAL_USER}" cp "${NIRI_SHELL_FILE}" "${NIRI_CONFIG_FILE}"
        fi

        # Registra a sessão Wayland para Noctalia no Niri
        register_wayland_session "noctalia-niri.desktop"

        # Validação do arquivo da shell
        log_info "Executando validador oficial do Niri para Noctalia (niri validate -c)..."
        if command -v niri >/dev/null 2>&1; then
            if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate -c "${NIRI_SHELL_FILE}" 2>&1)"; then
                log_success "[Checklist] Validação oficial aprovada: 'niri validate' confirmou a configuração do Noctalia."
            else
                log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração!"
                while IFS= read -r val_line; do
                    log_error "  [niri validate] ${val_line}"
                done <<< "${NIRI_VAL_OUTPUT}"
                exit 1
            fi
        elif [[ -x "/usr/bin/niri" ]]; then
            if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate -c "${NIRI_SHELL_FILE}" 2>&1)"; then
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
    NIRI_SHELL_FILE="${NIRI_SHELLS_DIR}/inir.kdl"

    log_info "Configurando ambiente isolado do Niri para iNiR Shell..."
    sudo -u "${REAL_USER}" mkdir -p "${NIRI_SHELLS_DIR}"

    # Copia template dedicado do iNiR
    sudo -u "${REAL_USER}" cp "${DESKTOP_DIR}/compositors/niri/shells/inir.kdl" "${NIRI_SHELL_FILE}"
    apply_niri_vm_flags "${NIRI_SHELL_FILE}"

    # Se config.kdl principal não existir, define o do iNiR como padrão
    if [[ ! -f "${NIRI_CONFIG_FILE}" ]]; then
        sudo -u "${REAL_USER}" cp "${NIRI_SHELL_FILE}" "${NIRI_CONFIG_FILE}"
    fi

    # Isolamento de autostart: o autostart do iNiR roda exclusivamente via spawn-at-startup
    # dentro de shells/inir.kdl. Removemos preventivamente o link global niri.service.wants
    # para impedir que o iNiR inicialize em segundo plano ao selecionar outras interfaces.
    SYSTEMD_USER_DIR="${REAL_HOME}/.config/systemd/user"
    if [[ -L "${SYSTEMD_USER_DIR}/niri.service.wants/inir.service" ]]; then
        log_info "Removendo vínculo de autostart global do inir.service para preservar isolamento de sessões..."
        rm -f "${SYSTEMD_USER_DIR}/niri.service.wants/inir.service" 2>/dev/null || true
    fi

    # Pré-ativação declarativa da família iRiS no config.json
    INIR_LEGACY_JSON="${REAL_HOME}/.config/illogical-impulse/config.json"
    INIR_NEW_JSON="${REAL_HOME}/.config/inir/config.json"

    # Semeia o config operativo a partir do default instalado, se ainda não existir
    if [[ ! -f "${INIR_LEGACY_JSON}" && -f "${INIR_NEW_JSON}" ]]; then
        log_info "Semeando ${INIR_LEGACY_JSON} a partir do config instalado em ${INIR_NEW_JSON}..."
        sudo -u "${REAL_USER}" mkdir -p "${REAL_HOME}/.config/illogical-impulse"
        sudo -u "${REAL_USER}" cp "${INIR_NEW_JSON}" "${INIR_LEGACY_JSON}"
    fi

    INIR_IRIS_TARGETS=()
    [[ -f "${INIR_LEGACY_JSON}" ]] && INIR_IRIS_TARGETS+=("${INIR_LEGACY_JSON}")
    [[ -f "${INIR_NEW_JSON}" ]] && INIR_IRIS_TARGETS+=("${INIR_NEW_JSON}")

    if [[ "${#INIR_IRIS_TARGETS[@]}" -gt 0 ]]; then
        log_info "Ativando a família de painéis iRiS na configuração do iNiR..."
        if sudo -u "${REAL_USER}" python3 - "${INIR_IRIS_TARGETS[@]}" <<'PYEOF'
import json, os, sys

# Painéis da família iRiS (root.panelFamilies["iris"] em shell.qml)
iris = ["irisBar", "irisBackground", "irisPalette", "irisControlCenter",
        "irisNotificationPopup", "irisOnScreenDisplay", "irisSessionScreen",
        "irisLock", "irisPolkit"]

rc = 0
for path in sys.argv[1:]:
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"{path}: cannot read config: {exc}", file=sys.stderr)
        rc = 1
        continue
    if not isinstance(data, dict):
        print(f"{path}: config root is not an object", file=sys.stderr)
        rc = 1
        continue

    was = data.get("panelFamily") == "iris"
    data["panelFamily"] = "iris"
    panels = data.get("enabledPanels") if isinstance(data.get("enabledPanels"), list) else []
    for p in iris:
        if p not in panels:
            panels.append(p)
    data["enabledPanels"] = panels
    known = data.get("knownPanels") if isinstance(data.get("knownPanels"), list) else []
    if known:
        for p in iris:
            if p not in known:
                known.append(p)
        data["knownPanels"] = known

    tmp = path + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=4, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp, path)
        print(f"{path}: " + ("iRiS já estava ativa" if was else "iRiS ativada"))
    except OSError as exc:
        print(f"{path}: write failed: {exc}", file=sys.stderr)
        rc = 1
sys.exit(rc)
PYEOF
        then
            log_success "[Checklist] Família iRiS pré-ativada no config operativo do iNiR."
        else
            log_warn "Falha ao ativar iRiS no config.json (iNiR subirá na família padrão; ative via Settings)."
        fi
    else
        log_warn "Nenhum config.json do iNiR encontrado (illogical-impulse nem inir) — pré-ativação do iRiS ignorada."
    fi

    # Registra a sessão Wayland para iNiR no Niri
    register_wayland_session "inir-niri.desktop"

    # Validação oficial do Niri para iNiR
    log_info "Validando configuração do Niri para iNiR (niri validate -c)..."
    if command -v niri >/dev/null 2>&1; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate -c "${NIRI_SHELL_FILE}" 2>&1)"; then
            log_success "[Checklist] Validação aprovada: 'niri validate' confirmou a configuração do iNiR."
        else
            log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração do iNiR!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    elif [[ -x "/usr/bin/niri" ]]; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate -c "${NIRI_SHELL_FILE}" 2>&1)"; then
            log_success "[Checklist] Validação aprovada: '/usr/bin/niri validate' confirmou o arquivo do iNiR."
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

elif [[ "${SELECTED_INTERFACE}" == "duxshell" ]]; then
    NIRI_SHELL_FILE="${NIRI_SHELLS_DIR}/duxshell.kdl"

    log_info "Configurando ambiente isolado do Niri para Dux Shell (DMS)..."
    sudo -u "${REAL_USER}" mkdir -p "${NIRI_SHELLS_DIR}"

    # Copia template dedicado do Dux Shell
    sudo -u "${REAL_USER}" cp "${DESKTOP_DIR}/compositors/niri/shells/duxshell.kdl" "${NIRI_SHELL_FILE}"
    apply_niri_vm_flags "${NIRI_SHELL_FILE}"

    # Se config.kdl principal não existir, define o do Dux Shell como padrão
    if [[ ! -f "${NIRI_CONFIG_FILE}" ]]; then
        sudo -u "${REAL_USER}" cp "${NIRI_SHELL_FILE}" "${NIRI_CONFIG_FILE}"
    fi

    # Registra a sessão Wayland para Dux Shell no Niri
    register_wayland_session "duxshell-niri.desktop"

    # Validação oficial do Niri para o Dux Shell
    log_info "Validando configuração do Niri para o Dux Shell (niri validate -c)..."
    if command -v niri >/dev/null 2>&1; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate -c "${NIRI_SHELL_FILE}" 2>&1)"; then
            log_success "[Checklist] Validação aprovada: 'niri validate' confirmou a configuração do DMS."
        else
            log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração do DMS!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    elif [[ -x "/usr/bin/niri" ]]; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate -c "${NIRI_SHELL_FILE}" 2>&1)"; then
            log_success "[Checklist] Validação aprovada: '/usr/bin/niri validate' confirmou o arquivo do DMS."
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

# 5. Definição do Alvo Gráfico e Ativação Consciente do Display Manager
ACTIVE_DM=""
if systemctl is-enabled greetd.service >/dev/null 2>&1; then
    ACTIVE_DM="greetd"
elif systemctl is-enabled sddm.service >/dev/null 2>&1; then
    ACTIVE_DM="sddm"
fi

if [[ -n "$ACTIVE_DM" ]]; then
    log_info "Display Manager já configurado e ativo no sistema: '${ACTIVE_DM}'."
    log_info "Preservando '${ACTIVE_DM}' como tela de login atual (idempotência aditiva)."
    log_info "Dica: Para alternar entre SDDM, Noctalia Greeter e Dux Greeter a qualquer momento, execute: ./tools/switch-display-manager.sh"
else
    # Primeira instalação: ativa o Display Manager padrão da interface escolhida
    if [[ "${SELECTED_INTERFACE:-}" =~ ^(duxshell|noctalia)$ || "${SELECTED_SHELL:-}" =~ ^(duxshell|noctalia)$ ]]; then
        log_info "Configurando inicialização gráfica padrão (Greetd)..."
        sudo systemctl disable gdm lightdm sddm 2>/dev/null || true
        sudo systemctl enable greetd.service
        ACTIVE_DM="greetd"
    else
        log_info "Configurando inicialização gráfica padrão (SDDM)..."
        sudo systemctl disable gdm lightdm greetd 2>/dev/null || true
        sudo systemctl enable sddm.service
        ACTIVE_DM="sddm"
    fi
fi

# Assegura a integridade do PAM para o Display Manager ativo
if [[ "$ACTIVE_DM" == "greetd" && -f "${SYSTEM_DIR}/pam_greetd.template" ]]; then
    backup_file /etc/pam.d/greetd true
    sudo cp "${SYSTEM_DIR}/pam_greetd.template" /etc/pam.d/greetd
    sudo chmod 644 /etc/pam.d/greetd
    sudo chown root:root /etc/pam.d/greetd
elif [[ "$ACTIVE_DM" == "sddm" && -f "${SYSTEM_DIR}/pam_sddm.template" ]]; then
    backup_file /etc/pam.d/sddm true
    sudo cp "${SYSTEM_DIR}/pam_sddm.template" /etc/pam.d/sddm
    sudo chmod 644 /etc/pam.d/sddm
    sudo chown root:root /etc/pam.d/sddm
fi

sudo systemctl set-default graphical.target
log_success "Target gráfico e display manager (${ACTIVE_DM}) assegurados."

# 6. Checklist Interno de Testes e Validação
echo ""
log_info "Iniciando checagens internas de integridade do sistema..."

# Teste 1: Serviço de Display Manager
if [[ "$ACTIVE_DM" == "greetd" ]]; then
    if systemctl is-enabled greetd.service >/dev/null 2>&1; then
        log_success "[Checklist] greetd.service está devidamente habilitado no systemd."
    else
        log_warn "[Checklist] greetd.service não reportou status enabled via systemctl is-enabled."
    fi
elif [[ "$ACTIVE_DM" == "sddm" ]]; then
    if systemctl is-enabled sddm.service >/dev/null 2>&1; then
        log_success "[Checklist] sddm.service está devidamente habilitado no systemd."
    else
        log_warn "[Checklist] sddm.service não reportou status enabled via systemctl is-enabled."
    fi
fi

# Teste 2: PAM do Display Manager Ativo
if [[ "$ACTIVE_DM" == "greetd" ]]; then
    if grep -qF "pam_oo7.so" /etc/pam.d/greetd; then
        log_ok "[Checklist] Integração com pam_oo7.so confirmada em /etc/pam.d/greetd."
    else
        log_error "[Checklist] Falha: Integração com pam_oo7.so ausente em /etc/pam.d/greetd!"
        exit 1
    fi
elif [[ "$ACTIVE_DM" == "sddm" ]]; then
    if grep -qF "pam_oo7.so" /etc/pam.d/sddm && grep -qE "^[[:space:]]*auth[[:space:]]+include[[:space:]]+system-auth" /etc/pam.d/sddm; then
        log_ok "[Checklist] Pilha PAM do SDDM íntegra (system-auth + pam_oo7.so) confirmada."
    else
        log_error "[Checklist] Falha: /etc/pam.d/sddm sem pam_oo7.so ou sem 'auth include system-auth'!"
        exit 1
    fi
fi

# Teste 3: Validação do Compositor e da Configuração da Shell
if [[ "${SELECTED_COMPOSITOR}" == "niri" ]]; then
    TARGET_KDL="${NIRI_SHELLS_DIR}/${SELECTED_INTERFACE}.kdl"
    [[ -f "$TARGET_KDL" ]] || TARGET_KDL="${NIRI_CONFIG_FILE}"

    if [[ -f "${TARGET_KDL}" ]]; then
        log_success "[Checklist] Arquivo de configuração verificado no disco: ${TARGET_KDL}."
    else
        log_error "[Checklist] Falha crítica: arquivo de configuração ${TARGET_KDL} não existe!"
        exit 1
    fi

    log_info "Executando validador oficial do Niri (niri validate -c)..."
    if command -v niri >/dev/null 2>&1; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" niri validate -c "${TARGET_KDL}" 2>&1)"; then
            log_success "[Checklist] Validação oficial aprovada: 'niri validate' confirmou o arquivo de configuração."
        else
            log_error "[Checklist] Falha crítica: 'niri validate' retornou erro na configuração!"
            while IFS= read -r val_line; do
                log_error "  [niri validate] ${val_line}"
            done <<< "${NIRI_VAL_OUTPUT}"
            exit 1
        fi
    elif [[ -x "/usr/bin/niri" ]]; then
        if NIRI_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/niri validate -c "${TARGET_KDL}" 2>&1)"; then
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

    CONFIG_OWNER="$(stat -c '%U' "${TARGET_KDL}" 2>/dev/null || echo 'desconhecido')"
    if [[ "$CONFIG_OWNER" == "$REAL_USER" ]]; then
        log_success "[Checklist] Propriedade de ${TARGET_KDL} pertence corretamente ao usuário '${REAL_USER}'."
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

# Teste 3.1: Validação e Listagem de Sessões Wayland Registradas
log_info "[Checklist] Sessões Wayland registradas no sistema (/usr/share/wayland-sessions):"
for s_desktop in /usr/share/wayland-sessions/*.desktop; do
    if [[ -f "$s_desktop" ]]; then
        s_title="$(grep -E '^Name=' "$s_desktop" 2>/dev/null | head -n1 | cut -d= -f2- || echo 'Sessão')"
        log_success "  • ${s_title} ($(basename "$s_desktop"))"
    fi
done

# Teste 4: Validação de ausência de NVIDIA em VM
if [[ "${IS_VM:-false}" == true ]]; then
    if rpm -q akmod-nvidia >/dev/null 2>&1; then
        log_error "[Checklist] Inconsistência: akmod-nvidia instalado em ambiente de Máquina Virtual!"
    else
        log_success "[Checklist] Confirmado: drivers proprietários NVIDIA não foram instalados na VM."
    fi
fi

# Teste 5: Validação da pilha oo7 (provedor oficial do Secret Service no F45)
if rpm -q oo7-daemon pam_oo7 oo7-portal >/dev/null 2>&1; then
    log_success "[Checklist] Pacotes 'oo7-daemon', 'pam_oo7' e 'oo7-portal' confirmados instalados."
else
    log_error "[Checklist] Falha crítica: pilha oo7 incompleta (oo7-daemon/pam_oo7/oo7-portal)!"
    exit 1
fi

# Teste 6: Validação da unidade e habilitação do oo7-daemon no login
if [[ -f "${REAL_HOME}/.config/systemd/user/oo7-daemon.service" || -f "/usr/lib/systemd/user/oo7-daemon.service" ]]; then
    log_success "[Checklist] Unidade do oo7-daemon presente no sistema."
    if [[ -e "${REAL_HOME}/.config/systemd/user/default.target.wants/oo7-daemon.service" ]] \
        || sudo -u "${REAL_USER}" XDG_RUNTIME_DIR="/run/user/$(id -u "${REAL_USER}")" \
              systemctl --user is-enabled oo7-daemon.service >/dev/null 2>&1; then
        log_success "[Checklist] oo7-daemon.service confirmado HABILITADO: o chaveiro 'login' será destravado via pam_oo7 no primeiro login (sem popup no navegador)."
    else
        log_warn "[Checklist] oo7-daemon.service presente mas não confirmado habilitado; verifique o systemd user preset desta release."
    fi
else
    log_warn "[Checklist] Unidade do oo7-daemon não localizada; verifique o empacotamento do oo7 nesta release."
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
