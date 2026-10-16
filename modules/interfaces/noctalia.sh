#!/usr/bin/env bash
# ==============================================================================
# fedora-inir: modules/shells/noctalia.sh
# Submódulo: Provedor do Desktop Shell Noctalia (C++/Qt)
# ==============================================================================
set -euo pipefail

log_info "Instalando pacote nativo noctalia via DNF..."
sudo dnf install -y noctalia

log_success "Submódulo Noctalia Shell configurado com sucesso."
