#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/interfaces/duxshell.sh
# Submódulo: Provedor e instalador do Dux Shell (DMS) via instalador da Dux Labs
# ==============================================================================
set -euo pipefail

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

log_info "Iniciando provisionamento do Dux Shell (DMS)..."

# 1. Renovação antecipada do timestamp administrativo do sudo
log_info "Renovando credenciais administrativas do sudo..."
sudo -v

# 2. Verificação defensiva de dependências essenciais
log_info "Verificando ferramentas e utilitários essenciais (curl, git, kitty)..."
MISSING_PKGS=()
for pkg in curl git kitty; do
    if ! command -v "${pkg}" >/dev/null 2>&1; then
        MISSING_PKGS+=("${pkg}")
    fi
done

if [[ "${#MISSING_PKGS[@]}" -gt 0 ]]; then
    log_info "Instalando dependências essenciais ausentes: ${MISSING_PKGS[*]}..."
    sudo dnf install -y "${MISSING_PKGS[@]}"
fi

# 3. Execução do instalador oficial da Dux Labs em modo Headless / Unattended
#    (install.duxlabs.dev substitui o antigo install.danklinux.com no rebrand 2.0;
#     as flags do dankinstall permanecem as mesmas: -c compositor, -t terminal, -y, --all-features)
log_info "Executando o instalador oficial do Dux Shell para o usuário ${REAL_USER}..."
sudo -u "${REAL_USER}" bash -c "curl -fsSL https://install.duxlabs.dev | sh -s -- -c niri -t kitty -y --all-features"

# 4. Auto-reparo de encapsulamento: assegurar PAM oo7 no Greetd pós-instalação Dux
log_info "Assegurando integração do PAM oo7 (Secret Service) no Greetd pós-instalação do Dux Shell..."
if [[ -f "${SYSTEM_DIR}/pam_greetd.template" ]]; then
    backup_file /etc/pam.d/greetd true
    sudo cp "${SYSTEM_DIR}/pam_greetd.template" /etc/pam.d/greetd
    sudo chmod 644 /etc/pam.d/greetd
    sudo chown root:root /etc/pam.d/greetd
fi

# 5. Isolamento de Sessões: impedir que o Dux Shell inicialize como serviço global de systemd
#    (O instalador da Dux habilita dms.service via niri.service.wants ou graphical-session.target.wants.
#     No Fedora Multi-Shell, cada shell é iniciada exclusivamente via spawn-at-startup no seu KDL
#     específico, evitando que o Dux Shell seja disparado em sessões de outras shells como Noctalia ou iNiR).
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

# 6. Assegurar posse e permissões estritas para o usuário real
log_info "Garantindo propriedade das pastas de configuração e dados para ${REAL_USER}..."
ensure_user_ownership "${REAL_HOME}/.config"
ensure_user_ownership "${REAL_HOME}/.local"

log_success "Submódulo Dux Shell (DMS) instalado e configurado com sucesso."
