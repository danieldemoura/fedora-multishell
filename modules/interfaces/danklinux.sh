#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/interfaces/danklinux.sh
# Submódulo: Provedor e instalador do DankMaterialShell (DMS) via dankinstall
# ==============================================================================
set -euo pipefail

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

log_info "Iniciando provisionamento do DankMaterialShell (DankLinux / DMS)..."

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

# 3. Execução do instalador oficial do DankLinux em modo Headless / Unattended
log_info "Executando o instalador oficial do DankLinux (dankinstall) para o usuário ${REAL_USER}..."
sudo -u "${REAL_USER}" bash -c "curl -fsSL https://install.danklinux.com | sh -s -- -c niri -t kitty -y --all-features"

# 4. Auto-reparo de encapsulamento: assegurar PAM GNOME Keyring no Greetd pós-dankinstall
log_info "Assegurando integração do PAM GNOME Keyring no Greetd pós-dankinstall..."
if [[ -f "${SYSTEM_DIR}/pam_greetd.template" ]]; then
    sudo cp "${SYSTEM_DIR}/pam_greetd.template" /etc/pam.d/greetd
    sudo chmod 644 /etc/pam.d/greetd
    sudo chown root:root /etc/pam.d/greetd
fi

# 5. Assegurar posse e permissões estritas para o usuário real
log_info "Garantindo propriedade das pastas de configuração e dados para ${REAL_USER}..."
ensure_user_ownership "${REAL_HOME}/.config"
ensure_user_ownership "${REAL_HOME}/.local"

log_success "Submódulo DankMaterialShell (DMS) instalado e configurado com sucesso."
