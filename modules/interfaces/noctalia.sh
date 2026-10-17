#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/shells/noctalia.sh
# Submódulo: Provedor do Desktop Shell Noctalia (C++/Qt)
# ==============================================================================
set -euo pipefail

CONF_FILE="${INSTALLER_ROOT}/config/packages-noctalia.conf"
install_packages_from_conf "${CONF_FILE}"

log_success "Submódulo Noctalia Shell configurado com sucesso."
