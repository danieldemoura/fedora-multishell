# PLANO DE IMPLEMENTAÇÃO E ESPECIFICAÇÃO TÉCNICA

## Projeto: Fedora Minimal (Netinstall) → Pure Wayland Workstation

**Stack Gráfica:** Niri (`yalter/niri`) + iNiR Shell (`snowarch/inir` via `quickshell`) + SDDM (`sddm` integrado e estilizado pelo iNiR)  

**Público-Alvo:** Desenvolvedor / Modelo de IA Gerador de Código  

**Versão Base Alvo:** Fedora 44 (x86_64)

---

## 1. DIRETRIZES DE ENGENHARIA E ARQUITETURA MODULAR

O script de instalação final **não deve ser construído como um arquivo monolítico**. Ele deve seguir os princípios de **Modularidade, Separação de Preocupações (SoC) e Facilidade de Manutenção**. A adição ou remoção de pacotes deve ser realizada alterando listas estáticas de texto/configuração, sem tocar na lógica do código de execução.

### 1.1 Estrutura de Diretórios Recomendada

O projeto é organizado na seguinte hierarquia:

```text
fedora-inir/
├── setup.sh                         # Ponto de entrada: checagens iniciais, menu e orquestração
├── config/
│   ├── packages-base.conf           # Lista de pacotes do sistema (Firmware, Áudio, SDDM, dependências iNiR, open-vm-tools, XDG)
│   ├── packages-apps.conf           # Aplicações essenciais de usuário, codecs multimídia e utilitários
│   ├── packages-flatpak.conf        # Lista declarativa de aplicativos Flatpak do Flathub
│   ├── packages-nvidia.conf         # Lista da pilha de drivers NVIDIA
│   └── settings.conf                # Variáveis globais (repositórios, versões, flags de ambiente)
├── lib/
│   ├── ui.sh                        # Funções de renderização visual (menu ANSI, banners, cores)
│   ├── logger.sh                    # Registro de logs (/tmp/fedora-inir-installer.log) e tratamento de erros
│   └── utils.sh                     # Funções utilitárias (validador de internet, sudo keepalive, permissões)
├── modules/
│   ├── 00_repos.sh                  # Inclusão e ativação de repositórios (RPM Fusion, COPRs Niri/Quickshell, Brave, Flathub)
│   ├── 01_system_hardware.sh        # Firmware, som (PipeWire), energia (Tuned) e rede
│   ├── 02_gpu_drivers.sh            # Drivers gráficos (Mesa livre ou NVIDIA se solicitado)
│   ├── 03_display_stack.sh          # SDDM e integração PAM
│   ├── 04_compositor_shell.sh       # Provisionamento Deno, Niri, Quickshell, Xwayland-satellite, iNiR e Portais
│   ├── 05_desktop_apps.sh           # Apps de uso diário, Loja GNOME Software, codecs multimídia e fontes
│   └── 06_post_install.sh           # Configuração do Niri (config.kdl), iNiR autostart, ABNT2, ativação do SDDM e validações
└── templates/
    └── pam_sddm.template            # Bloco do pam_gnome_keyring.so para o PAM do SDDM
```

### 1.2 Regras Estritas de Programação Shell

1. **Defensividade:** Todos os módulos devem rodar sob `set -euo pipefail`.

2. **Execução sem Root Direto:** O script deve recusar ser executado diretamente com `sudo ./setup.sh`. Ele deve ser iniciado pelo usuário comum (`./setup.sh`) e invocar `sudo` internamente apenas quando estritamente necessário.

3. **Idempotência:** A reexecução do script (ou de módulos individuais) não deve duplicar linhas em arquivos de configuração (`grep -qF` antes de inserir).

4. **Isolamento de Listas:** Os arquivos `.conf` na pasta `config/` (incluindo `packages-flatpak.conf` para aplicativos Flatpak) devem conter um pacote ou ID de aplicativo por linha, ignorando linhas que comecem com `#` e linhas vazias, permitindo que a IA ou o usuário adicione ou remova softwares apenas comentando uma linha.

---

## 2. DICIONÁRIO TÉCNICO E AUDITORIA DE PACOTES (POR REPOSITÓRIO)

Todos os pacotes a seguir foram auditados e confirmados para a base do **Fedora 44**.

### 2.1 Repositórios COPR (Niri e Quickshell)

| Pacote / COPR | Função e Importância no Sistema |
| :--- | :--- |
| `niri` (`yalter/niri`) | **Scrollable-Tiling Wayland Compositor:** Compositor moderno e fluido em Rust com rolagem horizontal infinita de colunas. |
| `quickshell` (`errornointernet/quickshell`) | **Framework QML para Desktop Shells:** Runtime reativo em C++/QtQuick/QML para interfaces Wayland de alto desempenho. |

### 2.2 Repositório Oficial do Fedora (fedora & updates)

| Pacote | Função e Importância no Sistema |
| :--- | :--- |
| `sddm` | **Display Manager / Gerenciador de Login:** Gerenciador moderno e robusto baseado em QML, com suporte oficial Wayland e totalmente estilizado pelo iNiR. |
| `open-vm-tools` | **Otimização de Máquina Virtual:** Suporte a compartilhamento de área de transferência, resolução dinâmica e integração em VMs. |
| `python3.12` & `python3.12-devel` | **Runtime Python:** Necessário para o virtualenv e execução dos daemons do iNiR. |
| `cairo-devel`, `cairo-gobject-devel`, `gobject-introspection-devel` | **Cabeçalhos C/GObject:** Evita falhas de compilação do `pycairo` e Meson na inicialização do iNiR. |
| `unzip` | **Extração:** Essencial para descompactação de runtimes (Deno) e pacotes zip. |
| `socat` & `mpv` | **IPC e Áudio do YouTube Music:** Comunicação via sockets UNIX e backend multimídia para o módulo de música do iNiR. |
| `xwayland-satellite` | **Servidor X11 Rootless Externo:** Permite que aplicações legadas X11 rodem de forma transparente no Niri. |
| `pipewire` & `wireplumber` | **Servidor Multimídia e Roteamento:** Gerenciamento moderno de áudio e vídeo de baixa latência. |
| `NetworkManager-wifi` & `wpa_supplicant` | **Conectividade Sem Fio:** Conexão e autenticação Wi-Fi com segurança WPA/WPA2/WPA3. |
| `bluez` & `bluez-tools` | **Pilha Bluetooth:** Pareamento de periféricos e áudio Bluetooth. |
| `dbus-broker` & `seatd` | **Barramento D-Bus e Acesso a Hardware:** Comunicação interprocessos e gerenciamento de assentos Wayland. |
| `udisks2` & `ntfs-3g` | **Gerenciamento de Armazenamento:** Montagem e suporte nativo a discos, partições e pendrives NTFS. |
| `polkit` | **Framework de Autorização:** Gerencia elevação de privilégios para tarefas administrativas. |
| `gnome-keyring` & `gnome-keyring-pam` | **Cofre de Chaves e Módulo PAM:** Desbloqueio transparente do chaveiro `login` na inicialização do SDDM. |
| `xdg-desktop-portal-gnome` & `xdg-desktop-portal-gtk` | **Backends de Portais Wayland:** Suporte a ScreenCast, Screenshot e caixas de diálogo nativas. |
| `@hardware-support` | **Firmwares Universais:** Cobertura de firmwares essenciais (Intel, AMD, Realtek, Broadcom, MediaTek). |
| `intel-microcode` / `amd-ucode-firmware` | **Microcódigo de CPU:** Atualizações de estabilidade e segurança para Intel ou AMD. |
| `tuned` & `tuned-ppd` | **Gerenciamento de Energia:** Otimização dinâmica de perfis de desempenho e economia de bateria. |
| `brightnessctl` & `upower` | **Brilho e Bateria:** Ajuste de iluminação de telas e teclados, e monitoramento da bateria. |
| `libinput` & `libinput-utils` | **Tratamento de Entrada:** Suporte completo a trackpads e gestos multitoque. |
| `nautilus`, `loupe`, `papers`, `gnome-text-editor`, `simple-scan`, `gnome-disk-utility` | **Aplicações de Produtividade:** Conjunto essencial moderno em GTK4/Libadwaita. |
| `kitty` & `fastfetch` | **Terminal Acelerado por GPU & Info:** Terminal padrão e resumo de hardware. |
| `swaylock` | **Bloqueador de Tela Wayland:** Bloqueio seguro via protocolo `ext-session-lock-v1`. |
| `grim`, `slurp`, `wl-clipboard` | **Captura de Tela & Clipboard:** Seleção interativa e cópia para a área de transferência Wayland. |
| `playerctl` | **Controle Multimídia (MPRIS):** Controle de mídia via teclas Play/Pause/Avançar. |
| `matugen` | **Gerador Material You:** Criação de esquemas de cores baseados em papéis de parede. |
| `google-noto-*-fonts` & `adwaita-icon-theme` | **Tipografia e Ícones:** Suporte tipográfico universal e conjunto de ícones padronizado. |
| `gnome-software` & `flatpak` | **Loja Gráfica e Gerenciador de Pacotes:** Gestão visual de Flatpaks integrados ao Flathub. |

---

## 3. DESIGN VISUAL DO MENU INTERATIVO CLI (ANSI/ASCII)

O instalador conta com uma interface em linha de comando elegante, padronizada e moderna utilizando caracteres Unicode e códigos de escape ANSI:

```text
  ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ 
  ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗
  █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║
  ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║
  ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║
  ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
  ── Niri + iNiR Shell + SDDM ──
  Fedora 44 Minimal | Pure Wayland | Out-of-the-box
```

---

## 4. DETALHAMENTO DE IMPLEMENTAÇÃO POR MÓDULO

### Módulo 00: Repositórios (`00_repos.sh`)
- Configuração do RPM Fusion Free e Nonfree.
- Habilitação idempotente dos COPRs:
  - `sudo dnf copr enable -y yalter/niri`
  - `sudo dnf copr enable -y errornointernet/quickshell`
- Adição do repositório oficial do Brave e Flathub.
- Sincronização e atualização de cache dos repositórios via `sudo dnf upgrade --refresh -y`.

### Módulo 01: Infraestrutura de Hardware e Áudio (`01_system_hardware.sh`)
- Detecção e instalação de microcódigos Intel/AMD.
- Instalação dos pacotes de `config/packages-base.conf` (incluindo `sddm` e `open-vm-tools`).
- Ativação de `tuned.service`, `NetworkManager`, `bluetooth`, `udisks2`, serviços de impressão e firewall para mDNS/IPP.

### Módulo 02: Drivers Gráficos e GPU (`02_gpu_drivers.sh`)
- Em VM (`IS_VM=true`): bypass imediato para evitar pacotes desnecessários.
- Em Bare Metal: instalação de Mesa DRI/Vulkan/VA-API e `switcheroo-control`. Se NVIDIA selecionado, instalação de `akmod-nvidia`, CUDA e serviços RTD3.

### Módulo 03: Pilha do Display Manager e Login (`03_display_stack.sh`)
- Instalação de `sddm` e `gnome-keyring-pam`.
- Atribuição dos grupos `video,render,input` ao usuário `sddm`.
- Integração PAM em `/etc/pam.d/sddm` com `pam_gnome_keyring.so` para desbloqueio transparente do cofre de senhas no login.

### Módulo 04: Compositor, Shell e Portais (`04_compositor_shell.sh`)
- Provisionamento defensivo do runtime oficial **Deno** em `/usr/local/bin/deno` baixado na home do usuário para evitar saturação do `/tmp`.
- Instalação via DNF: `niri`, `quickshell`, `xwayland-satellite`, `xdg-desktop-portal-gnome`, `xdg-desktop-portal-gtk`, `git`, `polkit`, `gnome-keyring`, `swaylock`.
- Configuração de prioridade de portais em `/etc/xdg/xdg-desktop-portal/niri-portals.conf`.
- Instalação do Desktop Shell iNiR:
  1. Clone de `https://github.com/snowarch/inir.git` para `${REAL_HOME}/.config/inir`.
  2. Execução não-interativa sob o usuário real:
     `sudo -u "${REAL_USER}" bash -c "cd '${REAL_HOME}/.config/inir' && ./setup install -y"`
  3. Garantia de posse `${REAL_USER}:${REAL_USER}` em toda a pasta `${REAL_HOME}/.config`.

### Módulo 05: Aplicações de Usuário e Multimídia (`05_desktop_apps.sh`)
- Swap `ffmpeg-free` por `ffmpeg`.
- Instalação dos pacotes de `config/packages-apps.conf` (incluindo `python3.12`, `python3.12-devel`, `cairo-devel`, `cairo-gobject-devel`, `gobject-introspection-devel`, `unzip`, `socat`, `mpv`, `matugen`, etc.).
- Instalação do Brave Origin (com contingência de script oficial).
- Instalação da GNOME Software com integração Flathub e aplicativos Flatpak declarativos (`config/packages-flatpak.conf`).

### Módulo 06: Pós-Instalação e Ajustes do Niri (`06_post_install.sh`)
- Inicialização preventiva do cofre PAM (`~/.local/share/keyrings/default` contendo `login` e permissão `600`).
- Configuração do Niri (`~/.config/niri/config.kdl`):
  1. Criação/cópia da configuração padrão se ausente.
  2. Injeção de autostart: `spawn-at-startup "inir" "run"`.
  3. Configuração do teclado ABNT2 (`layout "br"`) se `KEYBOARD_ABNT2=true`.
  4. Configurações para VM se `IS_VM=true`.
- Validação oficial da configuração com `sudo -u "${REAL_USER}" niri validate`.
- Ativação forçada do SDDM com `sudo systemctl enable --force sddm.service` e `sudo systemctl set-default graphical.target`.
- Checklist interno de testes e validações.

---

## 5. CRITÉRIOS DE TESTE E VALIDAÇÃO

- [x] **Validação do SDDM:** Testar se o serviço `sddm.service` está habilitado e a integração com `pam_gnome_keyring.so` está presente em `/etc/pam.d/sddm`.
- [x] **Validação do Niri:** Validar a configuração do Niri utilizando `sudo -u "$REAL_USER" niri validate`.
- [x] **Validação de Permissões:** Garantir que `~/.config` e `~/.local` pertençam ao usuário real (`$USER:$USER`).
- [x] **Validação de Driver na VM:** Garantir ausência de drivers proprietários NVIDIA quando em VM.
- [x] **Validação do Keyring e PAM:** Confirmar `gnome-keyring-pam` instalado, ponteiro `default` com conteúdo `login` e permissão `600`.
- [x] **Validação do Runtime Deno e Python 3.12:** Garantir que o Deno e pacotes de compilação C/Python estejam disponíveis para o YouTube Music do iNiR.
