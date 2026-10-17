#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/shells/noctalia.sh
# Submódulo: Provedor do Desktop Shell Noctalia (C++/Qt)
# ==============================================================================
set -euo pipefail

install_packages_from_conf "${CONFIG_DIR}/packages-noctalia.conf"

log_success "Submódulo Noctalia Shell configurado com sucesso."
