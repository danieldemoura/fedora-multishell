#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: setup.sh
# Ponto de entrada: checagens iniciais, menu interativo e orquestrador de módulos
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

# 4. Verificação de Conectividade e Elevação Sudo com Keepalive
check_internet
start_sudo_keepalive

# 5. Menu Interativo - Pergunta 1: Seleção de Ambiente
ui_section_header "SELEÇÃO DO AMBIENTE DE INSTALAÇÃO"
echo "  [1] Máquina Física (Bare Metal / Notebook / PC)"
echo "  [2] Máquina Virtual (VMware / VirtualBox / QEMU-KVM)"
echo ""
read -r -p "  Escolha uma opção: " env_choice
env_choice="${env_choice:-1}"

if [[ "$env_choice" == "2" ]]; then
    IS_VM=true
    ENV_DESC="Máquina Virtual (VM)"
else
    IS_VM=false
    ENV_DESC="Máquina Física (Bare Metal)"
fi

# Menu Interativo - Pergunta 2: Seleção da Interface Gráfica (Desktop Shell)
ui_section_header "SELEÇÃO DA INTERFACE GRÁFICA (DESKTOP SHELL)"
echo "  [1] iNiR Shell (Interface moderna com cores dinâmicas)"
echo "  [2] Noctalia Shell (Interface gráfica nativa em C++/Qt)"
echo ""
read -r -p "  Escolha uma opção: " shell_choice
shell_choice="${shell_choice:-1}"

if [[ "$shell_choice" == "2" ]]; then
    SELECTED_SHELL="noctalia"
    SHELL_DESC="Noctalia Shell (C++/Qt)"

    # Sub-pergunta de Compositor (apenas se Noctalia)
    echo ""
    echo "  Qual compositor Wayland você deseja utilizar com o Noctalia?"
    echo "    [1] Niri (Rolagem horizontal contínua de janelas)"
    echo "    [2] Umbriel (Rolagem e múltiplos modos de janelas)"
    echo ""
    read -r -p "  Escolha uma opção: " comp_choice
    comp_choice="${comp_choice:-1}"

    if [[ "$comp_choice" == "2" ]]; then
        SELECTED_COMPOSITOR="umbriel"
        COMP_DESC="Umbriel (Scrolling & Dynamic Tiling)"
    else
        SELECTED_COMPOSITOR="niri"
        COMP_DESC="Niri (Scrollable Tiling)"
    fi
else
    SELECTED_SHELL="inir"
    SHELL_DESC="iNiR Shell (Material You)"
    SELECTED_COMPOSITOR="niri"
    COMP_DESC="Niri (Scrollable Tiling)"
fi

# Menu Interativo - Pergunta 3: Driver de Vídeo Dedicado (NVIDIA)
if [[ "$IS_VM" == true ]]; then
    INSTALL_NVIDIA=false
    GPU_DESC="Mesa / Software Emulation"
else
    ui_section_header "DRIVER DE VÍDEO DEDICADO (NVIDIA)"
    read -r -p "  Deseja instalar os drivers proprietários da NVIDIA? [s/N]: " nvidia_choice
    nvidia_choice="${nvidia_choice:-n}"

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

# Menu Interativo - Pergunta 4: Configuração de Teclado
ui_section_header "CONFIGURAÇÃO DE TECLADO"
read -r -p "  Deseja configurar o padrão Brasileiro ABNT2 (com tecla ç)? [S/n]: " kbd_choice
kbd_choice="${kbd_choice:-s}"

if [[ "$kbd_choice" =~ ^[sSyY]$ ]]; then
    KEYBOARD_ABNT2=true
    KBD_DESC="Brasileiro (ABNT2 / br)"
else
    KEYBOARD_ABNT2=false
    KBD_DESC="Padrão do Sistema (US / Atual)"
fi

# Exporta variáveis para os módulos
export IS_VM
export SELECTED_SHELL
export SELECTED_COMPOSITOR
export INSTALL_NVIDIA
export KEYBOARD_ABNT2
export LOG_FILE

# 6. Resumo e Confirmação de Instalação
ui_summary_box "$ENV_DESC" "$SHELL_DESC" "$COMP_DESC" "$GPU_DESC" "$KBD_DESC"

read -r -p "  Deseja iniciar a instalação com estas definições? [S/n]: " confirm_install
confirm_install="${confirm_install:-s}"

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
    "06_desktop_shell.sh"
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
read -r -p "  Deseja reiniciar o sistema agora? [S/n]: " reboot_choice
reboot_choice="${reboot_choice:-s}"

if [[ "$reboot_choice" =~ ^[sSyY]$ ]]; then
    log_info "Reiniciando o sistema..."
    sudo reboot
else
    log_info "Instalação finalizada. Para iniciar a interface, execute manualmente: sudo reboot"
fi
