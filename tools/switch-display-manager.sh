#!/usr/bin/env bash
# ==============================================================================
# fedora-multishell: tools/switch-display-manager.sh
# Utilitário interativo para alternar a tela de login (Display Manager)
# Suporta: SDDM, Noctalia Greeter (Greetd) e Dux Greeter (Greetd)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Carregamento de configurações e bibliotecas do projeto
# shellcheck source=../config/settings.conf
[[ -f "${INSTALLER_ROOT}/config/settings.conf" ]] && source "${INSTALLER_ROOT}/config/settings.conf"
# shellcheck source=../lib/ui.sh
[[ -f "${INSTALLER_ROOT}/lib/ui.sh" ]] && source "${INSTALLER_ROOT}/lib/ui.sh"
# shellcheck source=../lib/logger.sh
[[ -f "${INSTALLER_ROOT}/lib/logger.sh" ]] && source "${INSTALLER_ROOT}/lib/logger.sh"
# shellcheck source=../lib/utils.sh
[[ -f "${INSTALLER_ROOT}/lib/utils.sh" ]] && source "${INSTALLER_ROOT}/lib/utils.sh"

check_not_root
log_init
enable_error_trap

ui_banner

log_info "Verificando privilégios administrativos (sudo)..."
if ! sudo -v; then
    log_error "Falha ao obter privilégios de sudo. O usuário atual deve pertencer ao grupo wheel."
    exit 1
fi

REAL_USER="$(get_real_user)"
GREETD_CONFIG="/etc/greetd/config.toml"

# 1. Identificação dos Display Managers instalados no sistema
INSTALLED_DMS=()
DM_KEYS=()

# Checagem: Noctalia Greeter (via Greetd)
if command -v noctalia-greeter >/dev/null 2>&1 || [[ -x "/usr/bin/noctalia-greeter" || -x "/usr/bin/noctalia-greeter-session" ]]; then
    INSTALLED_DMS+=("noctalia-greeter")
    DM_KEYS+=("Noctalia Greeter (Greetd)")
fi

# Checagem: Dux Greeter / DMS (via Greetd)
if command -v dms-greeter >/dev/null 2>&1 || [[ -x "/usr/bin/dms-greeter" ]]; then
    INSTALLED_DMS+=("dux-greeter")
    DM_KEYS+=("Dux Greeter (DMS / Greetd)")
fi

# Checagem: SDDM
if command -v sddm >/dev/null 2>&1 || [[ -x "/usr/bin/sddm" || -f "/usr/lib/systemd/system/sddm.service" ]]; then
    INSTALLED_DMS+=("sddm")
    DM_KEYS+=("SDDM (Simple Desktop Display Manager)")
fi

# Checagem de contingência: Greetd genérico (caso instalado sem greeter específico)
if command -v greetd >/dev/null 2>&1 || [[ -f "/usr/lib/systemd/system/greetd.service" ]]; then
    if [[ ! " ${INSTALLED_DMS[*]} " =~ "noctalia-greeter" ]] && [[ ! " ${INSTALLED_DMS[*]} " =~ "dux-greeter" ]]; then
        INSTALLED_DMS+=("greetd")
        DM_KEYS+=("Greetd (Generic)")
    fi
fi

if [[ "${#INSTALLED_DMS[@]}" -eq 0 ]]; then
    echo ""
    log_error "Nenhum Display Manager suportado (SDDM, Noctalia Greeter ou Dux Greeter) foi encontrado instalado."
    log_info "Execute o instalador principal (./install.sh) primeiro para provisionar a pilha gráfica."
    exit 1
fi

# 2. Identificação do Display Manager atualmente ativo
CURRENT_ACTIVE="nenhum"

if systemctl is-enabled sddm.service >/dev/null 2>&1; then
    CURRENT_ACTIVE="sddm"
elif systemctl is-enabled greetd.service >/dev/null 2>&1; then
    if [[ -f "$GREETD_CONFIG" ]] && grep -qF "noctalia-greeter" "$GREETD_CONFIG"; then
        CURRENT_ACTIVE="noctalia-greeter"
    elif [[ -f "$GREETD_CONFIG" ]] && grep -qF "dms-greeter" "$GREETD_CONFIG"; then
        CURRENT_ACTIVE="dux-greeter"
    else
        CURRENT_ACTIVE="greetd"
    fi
fi

# 3. Menu Interativo de Seleção
ui_section_header "SELEÇÃO DO GERENCIADOR DE LOGIN (DISPLAY MANAGER)"
echo "  Display Managers detectados no sistema:"
echo ""

VALID_OPTIONS=()
for i in "${!INSTALLED_DMS[@]}"; do
    num=$((i + 1))
    VALID_OPTIONS+=("$num")
    dm_id="${INSTALLED_DMS[$i]}"
    dm_name="${DM_KEYS[$i]}"

    if [[ "$dm_id" == "$CURRENT_ACTIVE" ]]; then
        echo -e "  [${num}] ${dm_name} \e[1;32m[ATIVO ATUALMENTE]\e[0m"
    else
        echo "  [${num}] ${dm_name}"
    fi
done

VALID_PATTERN="$(IFS='|'; echo "${VALID_OPTIONS[*]}")"
echo ""
ui_ask_choice "  Escolha qual gerenciador de login deseja ativar: " "1" "$VALID_PATTERN" dm_choice

SELECTED_INDEX=$((dm_choice - 1))
CHOSEN_DM="${INSTALLED_DMS[$SELECTED_INDEX]}"
CHOSEN_NAME="${DM_KEYS[$SELECTED_INDEX]}"

echo ""
if [[ "$CHOSEN_DM" == "$CURRENT_ACTIVE" ]]; then
    log_info "'${CHOSEN_NAME}' já é o gerenciador de login ativo no momento. Nenhuma alteração necessária."
    exit 0
fi

log_info "Configurando '${CHOSEN_NAME}' como gerenciador de login padrão..."

# 4. Aplicação da Troca
case "$CHOSEN_DM" in
    sddm)
        log_info "Desativando Greetd e ativando SDDM no systemd..."
        sudo systemctl disable greetd.service 2>/dev/null || true
        sudo systemctl enable sddm.service

        # Garante integração PAM oo7 no SDDM
        PAM_SDDM_TEMPLATE="${SYSTEM_DIR}/pam_sddm.template"
        if [[ -f "$PAM_SDDM_TEMPLATE" ]]; then
            log_info "Assegurando configuração de PAM para o SDDM (/etc/pam.d/sddm)..."
            sudo cp "$PAM_SDDM_TEMPLATE" /etc/pam.d/sddm
            sudo chmod 644 /etc/pam.d/sddm
            sudo chown root:root /etc/pam.d/sddm
        fi
        ;;

    noctalia-greeter)
        log_info "Configurando Greetd com Noctalia Greeter em ${GREETD_CONFIG}..."
        sudo mkdir -p /etc/greetd
        sudo mkdir -p /var/lib/noctalia-greeter
        sudo chown -R greetd:greetd /var/lib/noctalia-greeter 2>/dev/null || true

        if [[ "${IS_VM:-false}" == true ]]; then
            GREETER_CMD="env LIBGL_ALWAYS_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 /usr/bin/noctalia-greeter-session"
        else
            GREETER_CMD="/usr/bin/noctalia-greeter-session"
        fi

        GREETD_TEMPLATE="${SYSTEM_DIR}/greetd.toml.template"
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

        # Permissões do usuário greetd
        sudo usermod -aG video,render,input greetd 2>/dev/null || true

        # Sincronização passwordless se suportada
        if command -v noctalia-greeter >/dev/null 2>&1; then
            sudo noctalia-greeter passwordless-sync enable "${REAL_USER}" 2>/dev/null || true
        fi

        # Assegura PAM oo7 no Greetd
        PAM_GREETD_TEMPLATE="${SYSTEM_DIR}/pam_greetd.template"
        if [[ -f "$PAM_GREETD_TEMPLATE" ]]; then
            log_info "Assegurando configuração de PAM para o Greetd (/etc/pam.d/greetd)..."
            sudo cp "$PAM_GREETD_TEMPLATE" /etc/pam.d/greetd
            sudo chmod 644 /etc/pam.d/greetd
            sudo chown root:root /etc/pam.d/greetd
        fi

        log_info "Desativando SDDM e ativando Greetd no systemd..."
        sudo systemctl disable sddm.service 2>/dev/null || true
        sudo systemctl enable greetd.service
        ;;

    dux-greeter)
        log_info "Configurando Greetd com Dux Greeter (dms-greeter) em ${GREETD_CONFIG}..."
        sudo mkdir -p /etc/greetd

        GREETER_CMD="/usr/bin/dms-greeter"
        [[ -x "$GREETER_CMD" ]] || GREETER_CMD="dms-greeter"

        sudo tee "$GREETD_CONFIG" >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "${GREETER_CMD}"
user = "greetd"
EOF

        sudo usermod -aG video,render,input greetd 2>/dev/null || true

        PAM_GREETD_TEMPLATE="${SYSTEM_DIR}/pam_greetd.template"
        if [[ -f "$PAM_GREETD_TEMPLATE" ]]; then
            log_info "Assegurando configuração de PAM para o Greetd (/etc/pam.d/greetd)..."
            sudo cp "$PAM_GREETD_TEMPLATE" /etc/pam.d/greetd
            sudo chmod 644 /etc/pam.d/greetd
            sudo chown root:root /etc/pam.d/greetd
        fi

        log_info "Desativando SDDM e ativando Greetd no systemd..."
        sudo systemctl disable sddm.service 2>/dev/null || true
        sudo systemctl enable greetd.service
        ;;

    greetd)
        log_info "Ativando Greetd padrão no systemd..."
        sudo systemctl disable sddm.service 2>/dev/null || true
        sudo systemctl enable greetd.service
        ;;
esac

sudo systemctl set-default graphical.target >/dev/null 2>&1 || true

echo ""
log_success "Gerenciador de login alterado com sucesso para: ${CHOSEN_NAME}"
echo -e "  A nova tela de login será exibida na próxima inicialização do sistema."
echo ""
ui_ask_yn "  Deseja reiniciar o sistema agora para testar? [s/N]: " "n" reboot_choice
if [[ "$reboot_choice" =~ ^[sSyY]$ ]]; then
    log_info "Reiniciando o sistema..."
    sudo reboot
fi

