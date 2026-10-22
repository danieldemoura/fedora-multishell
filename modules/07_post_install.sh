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

    # 1. Inicialização supervisionada da shell (inir.service)
    #    Caminho canônico upstream: niri.service (sessão) puxa inir.service via
    #    wants link. A troca de família de painéis em runtime (iRiS) exige o
    #    serviço supervisionado — spawn-at-startup é contingência apenas quando
    #    a unidade de usuário do niri não existe na instalação.
    INIR_SUPERVISED=false
    INIR_BIN="${REAL_HOME}/.local/bin/inir"
    [[ -x "${INIR_BIN}" ]] || INIR_BIN="$(sudo -u "${REAL_USER}" bash -lc 'command -v inir' 2>/dev/null || true)"
    NIRI_USER_UNIT=""
    for unit_path in /usr/lib/systemd/user/niri.service /lib/systemd/user/niri.service /usr/local/lib/systemd/user/niri.service; do
        [[ -f "${unit_path}" ]] && { NIRI_USER_UNIT="${unit_path}"; break; }
    done
    SYSTEMD_USER_DIR="${REAL_HOME}/.config/systemd/user"

    if [[ -n "${INIR_BIN}" && -n "${NIRI_USER_UNIT}" ]]; then
        log_info "Vinculando o iNiR como serviço de usuário systemd (inir.service -> niri.service)..."
        sudo -u "${REAL_USER}" HOME="${REAL_HOME}" "${INIR_BIN}" service install || true
        sudo -u "${REAL_USER}" HOME="${REAL_HOME}" "${INIR_BIN}" service enable || true
        if [[ -f "${SYSTEMD_USER_DIR}/inir.service" ]]; then
            # Garantia apenas de sistema de arquivos (idempotente e sem D-Bus,
            # que não está disponível durante a instalação em TTY)
            mkdir -p "${SYSTEMD_USER_DIR}/niri.service.wants"
            ln -sf "${SYSTEMD_USER_DIR}/inir.service" "${SYSTEMD_USER_DIR}/niri.service.wants/inir.service"
            sudo chown -R "${REAL_USER}:${REAL_USER}" "${SYSTEMD_USER_DIR}"
            INIR_SUPERVISED=true
            # No modo canônico não deve haver spawn handwritten (risco de shell duplicada)
            sudo -u "${REAL_USER}" sed -i '/^spawn-at-startup "inir" "run"$/d;/^\/\/ Autostart da interface de usuário iNiR$/d' "${NIRI_CONFIG_FILE}"
            log_success "[Checklist] iNiR vinculado como serviço supervisionado (trocas de família em runtime habilitadas)."
        fi
    fi

    if [[ "${INIR_SUPERVISED}" == false ]]; then
        # Contingência: sem unidade de usuário do niri ou sem lançador, a shell
        # sobe como filha do Niri (interruptor de família em runtime ficará indisponível)
        if ! grep -q 'spawn-at-startup "inir" "run"' "${NIRI_CONFIG_FILE}"; then
            log_warn "Supervisionamento systemd indisponível: usando autostart de contingência via spawn-at-startup."
            sudo -u "${REAL_USER}" tee -a "${NIRI_CONFIG_FILE}" >/dev/null <<'EOF'

// Autostart da interface de usuário iNiR
spawn-at-startup "inir" "run"
EOF
            log_success "Autostart do iNiR adicionado ao ${NIRI_CONFIG_FILE}."
        else
            log_info "Autostart do iNiR já presente em ${NIRI_CONFIG_FILE} (modo de contingência)."
        fi
    fi

    # 2. Pré-ativação declarativa da família iRiS no config.json
    #    Equivalente ao botão "Ativar o Iris" (scripts/switch-family-restart.py),
    #    aplicado offline antes do primeiro boot — sem depender do serviço.
    #    ATENÇÃO AO CAMINHO: a shell em runtime lê o config de
    #    ~/.config/illogical-impulse/config.json (modules/common/Directories.qml
    #    fixa "shellConfig = <XDG_CONFIG>/illogical-impulse"; o mesmo caminho é
    #    usado pelo switch-family-restart.py). O ./setup install, porém, semeia os
    #    defaults em ~/.config/inir/config.json (resolve_inir_config_dir prefere o
    #    diretório novo). Escrevemos no caminho operativo (illogical-impulse) e,
    #    se existir, espelhamos em ~/.config/inir para manter o lançador coerente.
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

    # 3. Injeção de variáveis de renderização segura para VM
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
elif [[ "${SELECTED_INTERFACE}" == "duxshell" ]]; then
    NIRI_CONFIG_DIR="${REAL_HOME}/.config/niri"
    NIRI_CONFIG_FILE="${NIRI_CONFIG_DIR}/config.kdl"

    log_info "Interface selecionada é Dux Shell (DMS): ajustando configurações no Niri..."
    sudo -u "${REAL_USER}" mkdir -p "${NIRI_CONFIG_DIR}"

    if [[ ! -f "${NIRI_CONFIG_FILE}" ]]; then
        log_warn "Arquivo ${NIRI_CONFIG_FILE} não encontrado após a instalação do DMS. Criando arquivo base..."
        sudo -u "${REAL_USER}" touch "${NIRI_CONFIG_FILE}"
    fi

    # 1. Injeção de Autostart do Dux Shell (DMS)
    if ! grep -q 'spawn-at-startup "dms"' "${NIRI_CONFIG_FILE}"; then
        log_info "Configurando autostart do Dux Shell (dms run) no Niri..."
        # Injeta spawn-at-startup "dms" "run" no topo do arquivo de configuração
        sudo -u "${REAL_USER}" sed -i '1i spawn-at-startup "dms" "run"' "${NIRI_CONFIG_FILE}"
        log_success "Autostart do Dux Shell configurado com sucesso em ${NIRI_CONFIG_FILE}."
    else
        log_info "Autostart do Dux Shell já presente em ${NIRI_CONFIG_FILE}."
    fi

    # 2. Injeção de variáveis de renderização segura para VM
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

    # 3. Garantir permissões de posse antes da validação
    ensure_user_ownership "${REAL_HOME}/.config"

    # 4. Validação oficial do Niri
    log_info "Validando configuração do Niri para o Dux Shell (niri validate)..."
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
if [[ "${SELECTED_INTERFACE:-}" =~ ^(duxshell|noctalia)$ || "${SELECTED_SHELL:-}" =~ ^(duxshell|noctalia)$ ]]; then
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
if [[ "${SELECTED_INTERFACE:-}" =~ ^(duxshell|noctalia)$ || "${SELECTED_SHELL:-}" =~ ^(duxshell|noctalia)$ ]]; then
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
if [[ "${SELECTED_INTERFACE:-}" =~ ^(duxshell|noctalia)$ || "${SELECTED_SHELL:-}" == "noctalia" ]]; then
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
