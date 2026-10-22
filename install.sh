#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: install.sh
# Ponto de entrada: validações, menu interativo pt-BR e orquestrador de módulos
# ==============================================================================
set -euo pipefail

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregamento de Configurações e Bibliotecas
# shellcheck source=config/settings.conf
source "${INSTALLER_ROOT}/config/settings.conf"
# shellcheck source=lib/ui.sh
source "${INSTALLER_ROOT}/lib/ui.sh"
# shellcheck source=lib/logger.sh
source "${INSTALLER_ROOT}/lib/logger.sh"
# shellcheck source=lib/utils.sh
source "${INSTALLER_ROOT}/lib/utils.sh"

# 1. Validação de Execução (Não permitir execução direta como root)
check_not_root

# 2. Inicialização de Logs e Tratamento de Erros
log_init
enable_error_trap

# 3. Banner Visual
ui_banner

# 4. Verificação de Conectividade e Homologação da Release
check_internet

FEDORA_VER="$(rpm -E %fedora 2>/dev/null || echo 0)"
log_info "Detectada distribuição: Fedora ${FEDORA_VER}"
if [[ "${FEDORA_VER}" != "${TARGET_FEDORA_VERSION}" ]]; then
    log_warn "Este instalador foi homologado para o Fedora ${TARGET_FEDORA_VERSION} (detectado: ${FEDORA_VER})."
    log_warn "Nomes de pacotes, repositórios e versões podem divergir nessa release."
    ui_ask_yn "  Deseja continuar mesmo assim? [s/N]: " "n" proceed_choice
    if ! [[ "$proceed_choice" =~ ^[sSyY]$ ]]; then
        log_warn "Operação cancelada pelo usuário. Nenhuma alteração foi realizada no sistema."
        exit 0
    fi
fi

log_info "Verificando privilégios administrativos (sudo)..."
if ! sudo -v; then
    log_error "Falha ao obter privilégios de sudo. O usuário atual deve pertencer ao grupo wheel."
    exit 1
fi

REAL_USER="$(get_real_user)"
if [[ -z "${REAL_USER}" ]]; then
    log_error "Não foi possível identificar o usuário real (variáveis USER/SUDO_USER ausentes)."
    exit 1
fi

SUDOERS_TEMP="/etc/sudoers.d/99-fedora-installer-temp"
SUDOERS_BUILD_TMP=""

# Regra de sudoers temporária:
# - Drop-in órfão de execução anterior morta por SIGKILL/queda é removido antes;
# - A regra é validada sintaticamente com visudo -cf antes de entrar em /etc;
# - O trap (EXIT HUP INT TERM) autodestrói a regra no encerramento.
if sudo test -f "${SUDOERS_TEMP}"; then
    log_warn "Removendo regra temporária de sudoers órfã de uma instalação anterior."
    sudo rm -f "${SUDOERS_TEMP}"
fi

trap 'cleanup_installer' EXIT HUP INT TERM

log_info "Habilitando privilégios temporários sem senha para a instalação..."
SUDOERS_BUILD_TMP="$(mktemp)"
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${REAL_USER}" > "${SUDOERS_BUILD_TMP}"
if ! sudo visudo -cf "${SUDOERS_BUILD_TMP}" >/dev/null 2>&1; then
    log_error "Regra de sudoers temporária inválida gerada para o usuário '${REAL_USER}'. Abortando."
    exit 1
fi
sudo install -m 0440 -o root -g root "${SUDOERS_BUILD_TMP}" "${SUDOERS_TEMP}"
rm -f "${SUDOERS_BUILD_TMP}"
SUDOERS_BUILD_TMP=""

# 5. Menu Interativo - Pergunta 1: Seleção de Ambiente
ui_section_header "SELEÇÃO DO AMBIENTE DE INSTALAÇÃO"
echo "  [1] Máquina Física (Bare Metal / Notebook / PC)"
echo "  [2] Máquina Virtual (VMware / VirtualBox / QEMU-KVM)"
echo ""
ui_ask_choice "  Escolha uma opção: " "1" "1|2" env_choice

if [[ "$env_choice" == "2" ]]; then
    IS_VM=true
    ENV_DESC="Máquina Virtual (VM)"
else
    IS_VM=false
    ENV_DESC="Máquina Física (Bare Metal)"
fi

# Menu Interativo - Pergunta 2: Seleção da Interface Gráfica (Desktop Shell / Interface)
ui_section_header "SELEÇÃO DA INTERFACE GRÁFICA (DESKTOP SHELL)"
echo "  [1] iNiR Shell"
echo "  [2] Noctalia Shell"
echo "  [3] Dux Shell (DMS)"
echo ""
ui_ask_choice "  Escolha uma opção: " "1" "1|2|3" shell_choice

if [[ "$shell_choice" == "2" ]]; then
    SELECTED_INTERFACE="noctalia"
    SHELL_DESC="Noctalia Shell"

    # Sub-pergunta de Compositor (apenas se Noctalia)
    echo ""
    echo "  Qual compositor Wayland você deseja utilizar com o Noctalia?"
    echo "    [1] Niri (Rolagem horizontal contínua de janelas)"
    echo "    [2] Umbriel (Rolagem e múltiplos modos de janelas)"
    echo ""
    ui_ask_choice "  Escolha uma opção: " "1" "1|2" comp_choice

    if [[ "$comp_choice" == "2" ]]; then
        SELECTED_COMPOSITOR="umbriel"
        COMP_DESC="Umbriel (Scrolling & Dynamic Tiling)"
    else
        SELECTED_COMPOSITOR="niri"
        COMP_DESC="Niri (Scrollable Tiling)"
    fi
elif [[ "$shell_choice" == "3" ]]; then
    SELECTED_INTERFACE="duxshell"
    SHELL_DESC="Dux Shell"
    SELECTED_COMPOSITOR="niri"
    COMP_DESC="Niri (Scrollable Tiling)"
else
    SELECTED_INTERFACE="inir"
    SHELL_DESC="iNiR Shell (Material You)"
    SELECTED_COMPOSITOR="niri"
    COMP_DESC="Niri (Scrollable Tiling)"
fi

# Compatibilidade retroativa com módulos legados
SELECTED_SHELL="${SELECTED_INTERFACE}"

# Menu Interativo - Pergunta 3: Driver de Vídeo Dedicado (NVIDIA)
if [[ "$IS_VM" == true ]]; then
    INSTALL_NVIDIA=false
    GPU_DESC="Mesa / Software Emulation"
else
    ui_section_header "DRIVER DE VÍDEO DEDICADO (NVIDIA)"
    ui_ask_yn "  Deseja instalar os drivers proprietários da NVIDIA? [s/N]: " "n" nvidia_choice

    if [[ "$nvidia_choice" =~ ^[sSyY]$ ]]; then
        INSTALL_NVIDIA=true
        GPU_DESC="NVIDIA Proprietário (akmods)"
        # Exibe banner educativo obrigatório sobre Secure Boot na BIOS
        ui_secure_boot_warning
    else
        INSTALL_NVIDIA=false
        GPU_DESC="Mesa Open-Source (Intel/AMD/Nouveau)"
    fi
fi

# Exporta variáveis para os módulos
export IS_VM
export SELECTED_INTERFACE
export SELECTED_SHELL
export SELECTED_COMPOSITOR
export INSTALL_NVIDIA
export LOG_FILE

# 6. Resumo e Confirmação de Instalação
ui_summary_box "$ENV_DESC" "$SHELL_DESC" "$COMP_DESC" "$GPU_DESC"

ui_ask_yn "  Deseja iniciar a instalação com estas definições? [S/n]: " "s" confirm_install

if [[ ! "$confirm_install" =~ ^[sSyY]$ ]]; then
    echo ""
    log_warn "Operação cancelada pelo usuário. Nenhuma alteração foi realizada no sistema."
    exit 0
fi

START_TIME=$(date +%s)
echo ""
log_info "Iniciando processo de instalação modular do Fedora Workstation..."

# 7. Execução Sequencial dos Módulos (Arquitetura em Camadas)
modules=(
    "00_repos.sh"
    "01_system_hardware.sh"
    "02_gpu_drivers.sh"
    "03_desktop_apps.sh"
    "04_display_stack.sh"
    "05_compositor.sh"
    "06_desktop_interface.sh"
    "07_post_install.sh"
)

for mod in "${modules[@]}"; do
    mod_path="${INSTALLER_ROOT}/modules/${mod}"
    if [[ -f "$mod_path" ]]; then
        chmod +x "$mod_path"
        log_info "Executando: ${mod}..."
        bash "$mod_path"
    else
        log_error "Módulo obrigatório não encontrado: ${mod_path}"
        exit 1
    fi
done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_DURATION / 60))
SECONDS=$((TOTAL_DURATION % 60))

# 8. Finalização e Sucesso
echo ""
echo -e "${CLR_GREEN}"
echo "  ╔═════════════════════════════════════════════════════════════════════╗"
echo "  ║ 🎉  INSTALAÇÃO CONCLUÍDA COM SUCESSO!                              ║"
echo "  ╚═════════════════════════════════════════════════════════════════════╝"
echo -e "${CLR_RESET}"
echo -e "  Tempo total de instalação: ${CLR_BOLD}${MINUTES}m ${SECONDS}s${CLR_RESET}"
echo -e "  Log completo da instalação: ${CLR_CYAN}${LOG_FILE}${CLR_RESET}"
echo ""

if [[ "${INSTALL_NVIDIA:-false}" == true ]] && [[ "${IS_VM:-false}" == false ]]; then
    echo -e "${CLR_YELLOW}[LEMBRETE IMPORTANTE DE HARDWARE]${CLR_RESET}"
    echo -e "  Se o seu computador possui ${CLR_BOLD}Secure Boot ativado na BIOS${CLR_RESET},"
    echo -e "  reinicie, entre na BIOS e desative-o para carregar o driver NVIDIA."
    echo ""
fi

echo -e "  Seu sistema está pronto para inicializar na interface ${CLR_BOLD}${SHELL_DESC} (${COMP_DESC})${CLR_RESET}."
echo ""
ui_ask_yn "  Deseja reiniciar o sistema agora? [S/n]: " "s" reboot_choice

if [[ "$reboot_choice" =~ ^[sSyY]$ ]]; then
    log_info "Reiniciando o sistema..."
    sudo reboot
else
    log_info "Instalação finalizada. Para iniciar a interface, execute manualmente: sudo reboot"
fi
