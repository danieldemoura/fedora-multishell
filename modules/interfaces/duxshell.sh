#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/interfaces/duxshell.sh
# Submódulo: Provedor e instalador do Dux Shell (DMS) via instalador da Dux Labs
# ==============================================================================
set -euo pipefail

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

log_info "Iniciando provisionamento do Dux Shell (DMS)..."

# 1. Instalação declarativa dos pacotes oficiais via duxlabs/dms e duxlabs/dux-repo
log_info "Removendo versões legadas com nomes antigos do DankMaterialShell (1.x) para evitar conflitos..."
sudo dnf remove -y DankMaterialShell dms-greeter danksearch dankcalendar 2>/dev/null || true

log_info "Instalando a suíte moderna Dux Shell (DMS 2.x)..."
install_packages_from_conf "${PACKAGES_DIR}/duxshell.conf"
sudo dnf upgrade --refresh -y dms dux-greeter dsearch dcal 2>/dev/null || true

# 2. Auto-reparo de encapsulamento: assegurar PAM oo7 no Greetd pós-instalação Dux
log_info "Assegurando integridade e permissões da integração do PAM oo7 no Greetd..."
if [[ -f "${SYSTEM_DIR}/pam_greetd.template" ]]; then
    backup_file /etc/pam.d/greetd true
    sudo cp "${SYSTEM_DIR}/pam_greetd.template" /etc/pam.d/greetd
    sudo chmod 644 /etc/pam.d/greetd
    sudo chown root:root /etc/pam.d/greetd
fi

# 3. Isolamento de Sessões: impedir que o Dux Shell inicialize como serviço global de systemd
#    (Evita que o dms seja disparado em sessões de outras shells como Noctalia ou iNiR).
log_info "Garantindo isolamento do Dux Shell no systemd (desativando inicialização global não intencional)..."
SYSTEMD_USER_DIR="${REAL_HOME}/.config/systemd/user"
for want_dir in "${SYSTEMD_USER_DIR}/niri.service.wants" \
               "${SYSTEMD_USER_DIR}/graphical-session.target.wants" \
               "${SYSTEMD_USER_DIR}/default.target.wants"; do
    if [[ -d "$want_dir" ]]; then
        sudo -u "${REAL_USER}" rm -f "${want_dir}/dms.service" "${want_dir}/dux.service" 2>/dev/null || true
    fi
done
# Desabilita o serviço dms no systemctl --user de forma defensiva se o daemon de usuário estiver acessível
if command -v systemctl >/dev/null 2>&1; then
    sudo -u "${REAL_USER}" XDG_RUNTIME_DIR="/run/user/$(id -u "${REAL_USER}")" \
        systemctl --user disable dms.service dux.service >/dev/null 2>&1 || true
fi

# 4. Assegurar posse e permissões estritas para o usuário real
log_info "Garantindo propriedade das pastas de configuração e dados para ${REAL_USER}..."
ensure_user_ownership "${REAL_HOME}/.config"
ensure_user_ownership "${REAL_HOME}/.local"

log_success "Submódulo Dux Shell (DMS) instalado e configurado com sucesso."
