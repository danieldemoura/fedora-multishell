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
│   ├── 04_compositor.sh             # Compositor Niri, Quickshell, Deno (/usr/local/bin), Xwayland-satellite e Portais
│   ├── 05_desktop_apps.sh           # Apps de uso diário, Loja GNOME Software, codecs multimídia e fontes
│   ├── 06_inir_shell.sh             # Módulo Dedicado Shell: sudo -v antecipado, clone, ./setup install -y e permissões
│   └── 07_post_install.sh           # Configuração do Niri (config.kdl), iNiR autostart, ABNT2, ativação do SDDM e validações
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

### Módulo 04: Isolamento do Compositor Wayland (`04_compositor.sh`)
- Provisionamento preventivo do runtime oficial **Deno** em `/usr/local/bin/deno` baixado diretamente no `$HOME` (`${REAL_HOME}`) do usuário para não esgotar a partição tmpfs do `/tmp`.
- Instalação via DNF exclusivamente dos componentes centrais e pontes do compositor:
  `niri`, `quickshell`, `xwayland-satellite`, `xdg-desktop-portal-gnome`, `xdg-desktop-portal-gtk`, `git`, `polkit`, `gnome-keyring`, `swaylock`.
- Configuração do arquivo de portais em `/etc/xdg/xdg-desktop-portal/niri-portals.conf`.
- Remoção completa de clonagem ou execução do shell iNiR deste módulo (responsabilidade transferida para o Módulo 06).

### Módulo 05: Aplicações de Usuário e Multimídia (`05_desktop_apps.sh`)
- Swap `ffmpeg-free` por `ffmpeg`.
- Instalação dos pacotes de `config/packages-apps.conf`.
- Instalação do Brave Origin (com contingência de script oficial).
- Instalação da GNOME Software com integração Flathub e aplicativos Flatpak declarativos (`config/packages-flatpak.conf`).

### Módulo 06: Módulo Dedicado do Shell (`06_inir_shell.sh`)
- Única responsabilidade: compilar e configurar o Desktop Shell do iNiR.
- **Renovação Antecipada do Sudo:** Execução de `sudo -v` logo no início para atualizar o timestamp administrativo, garantindo que as chamadas internas de `sudo` do instalador do iNiR herdem o acesso sem pausar o terminal pedindo senha.
- **Clonagem do iNiR:** Clone de `https://github.com/snowarch/inir.git` para `${REAL_HOME}/.config/inir` caso o diretório ainda não exista.
- **Instalação Não-Interativa sob Usuário Real:**
  `sudo -u "${REAL_USER}" bash -c "cd '${REAL_HOME}/.config/inir' && ./setup install -y"`
- **Correção de Permissões:** `chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.config/inir"`.

### Módulo 07: Pós-Instalação do Sistema e Validações (`07_post_install.sh`)
- Finalização do sistema operacional e testes de integridade:
  1. **Chaveiro PAM:** Criação preventiva de `~/.local/share/keyrings/default` com conteúdo `login` e permissão `600`.
  2. **Configuração do Niri (`~/.config/niri/config.kdl`):**
     - Copiar o template padrão caso ausente.
     - Injetar a linha de autostart: `spawn-at-startup "inir" "run"`.
     - Configurar teclado ABNT2 (`layout "br"`) se `KEYBOARD_ABNT2=true`.
     - Injetar flags de renderização se `IS_VM=true`.
  3. **Diretórios de Usuário e Permissões:**
     - Executar `sudo -u "${REAL_USER}" xdg-user-dirs-update`.
     - Garantir que `${REAL_HOME}/.config` e `${REAL_HOME}/.local` pertençam recursivamente ao `${REAL_USER}:${REAL_USER}`.
  4. **Ativação Defensiva do SDDM:**
     - Desativação de outros gerenciadores e ativação forçada do SDDM:
       ```bash
       sudo systemctl disable gdm lightdm greetd 2>/dev/null || true
       sudo systemctl enable --force sddm.service
       sudo systemctl set-default graphical.target
       ```
  5. **Compilação NVIDIA:** Se `INSTALL_NVIDIA=true`, executar `sudo akmods --force`.
  6. **Validações Finais:** Executar `sudo -u "${REAL_USER}" niri validate` e registrar o checklist final no log.

---

## 5. REGISTRO FORMAL DE DECISÕES DE PROGRAMAÇÃO DEFENSIVA E CASOS DE BORDA

| Decisão Arquitetural / Defensiva | Justificativa Técnica e Prevenção de Falhas |
| :--- | :--- |
| **`sudo systemctl disable gdm lightdm greetd` em sistema minimal** | Atua como rede de segurança essencial para evitar conflitos de display manager caso o usuário reexecute o instalador (desativando instâncias do Greetd de testes anteriores) ou caso o script seja rodado sobre Fedora Workstation/Spins que contenham GDM/LightDM pré-instalados. Evita dois serviços de login competindo pelo mesmo DRM/KMS. |
| **Renovação Antecipada do Sudo (`sudo -v`) no Módulo 06** | O timeout padrão de credenciais administrativas do `sudo` no Linux varia tipicamente entre 5 e 15 minutos. Em conexões lentas ou etapas anteriores demoradas (como download de pacotes no Módulo 05), as credenciais expiram. Renovar explicitamente o timestamp com `sudo -v` antes de acionar `./setup install -y` do iNiR garante que seus comandos internos rodando com privilégios não pausam a execução em segundo plano para pedir senha interativamente. |
| **Layout de Teclado (`layout "br"`) vs Idioma da Interface** | O parâmetro `layout "br"` injetado no bloco `xkb` do Niri afeta exclusivamente a tabela física de mapeamento dos scancodes do hardware (viabilizando a tecla `Ç`, `~`, `^` e pontuações do padrão brasileiro ABNT2), operando de forma totalmente independente e desacoplada do idioma da interface gráfica ou widgets do iNiR (que permanecem em inglês nativo). |
| **Download do Deno no `$HOME` em vez de `/tmp`** | Em sistemas Fedora modernos, `/tmp` é montado como `tmpfs` residente em memória RAM, frequentemente com limite de 50% da memória física ou restrições severas de inodes/blocos. Durante downloads paralelos ou compilações simultâneas em máquinas virtuais com pouca memória (ex: 2GB-4GB), extrair arquivos no `/tmp` provoca erro de *No space left on device* (`curl: (23) Failure writing output to destination`). Utilizar `${REAL_HOME}` protege contra o esgotamento da partição temporária em memória. |

---

## 6. CRITÉRIOS DE TESTE E VALIDAÇÃO

- [x] **Validação do SDDM:** Testar se o serviço `sddm.service` está habilitado e a integração com `pam_gnome_keyring.so` está presente em `/etc/pam.d/sddm`.
- [x] **Validação do Niri:** Validar a configuração do Niri utilizando `sudo -u "$REAL_USER" niri validate`.
- [x] **Validação de Permissões:** Garantir que `~/.config` e `~/.local` pertençam ao usuário real (`$USER:$USER`).
- [x] **Validação de Driver na VM:** Garantir ausência de drivers proprietários NVIDIA quando em VM.
- [x] **Validação do Keyring e PAM:** Confirmar `gnome-keyring-pam` instalado, ponteiro `default` com conteúdo `login` e permissão `600`.
- [x] **Validação do Runtime Deno e Python 3.12:** Garantir que o Deno e pacotes de compilação C/Python estejam disponíveis para o YouTube Music do iNiR.
