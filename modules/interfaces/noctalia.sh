#!/usr/bin/env bash
# ==============================================================================
# fedora-multi-shell: modules/interfaces/noctalia.sh
# Submódulo: Provedor do Desktop Shell Noctalia (C++/Qt)
# ==============================================================================
set -euo pipefail

install_packages_from_conf "${PACKAGES_DIR}/noctalia.conf"

log_success "Submódulo Noctalia Shell configurado com sucesso."
