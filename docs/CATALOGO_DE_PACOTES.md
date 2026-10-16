# 📦 Catálogo de Pacotes e Dependências do Sistema

Este documento apresenta a especificação técnica completa de todos os pacotes, bibliotecas, drivers e componentes provisionados pelo projeto **Fedora Multi-Shell**.

A arquitetura do instalador opera sob rigorosa transparência técnica e modularidade em camadas:
- **Camadas Declarativas Fixas:** Pacotes mantidos e auditáveis nos arquivos de configuração do diretório `config/`.
- **Provisionamento Dinâmico de Módulos:** Pacotes instalados condicionalmente via DNF pelos submódulos em `modules/` de acordo com a seleção de compositores, interfaces gráficas e navegadores.
- **Ecossistemas e Componentes de Terceiros:** Runtimes, scripts upstream e suites desktop configurados por instaladores oficiais de seus respectivos mantenedores.

> 🤝 **Convite à Comunidade e Desenvolvedores:** Este catálogo foi concebido para ser auditável. Sugestões de novos pacotes, atualizações de dependências e melhorias de compatibilidade Wayland puro são sempre bem-vindas via _Pull Request_.

---

## 📑 Sumário

1. [Diretrizes de Rastreabilidade e Proveniência](#-diretrizes-de-rastreabilidade-e-proveniência)
2. [Categoria A: Pacotes Declarativos Fixos (`config/`)](#-categoria-a-pacotes-declarativos-fixos-config)
   - [Pacotes Base do Sistema (`config/packages-base.conf`)](#1-pacotes-base-do-sistema-configpackages-baseconf)
   - [Aplicações de Usuário e Multimídia (`config/packages-apps.conf`)](#2-aplicações-de-usuário-e-multimídia-configpackages-appsconf)
   - [Drivers Proprietários NVIDIA (`config/packages-nvidia.conf`)](#3-drivers-proprietários-nvidia-configpackages-nvidiaconf)
   - [Aplicações Flatpak do Flathub (`config/packages-flatpak.conf`)](#4-aplicações-flatpak-do-flathub-configpackages-flatpakconf)
3. [Categoria B: Pacotes Oficiais Instalados por Módulos (`modules/*.sh`)](#-categoria-b-pacotes-oficiais-instalados-por-módulos-modules)
4. [Categoria C: Ecossistemas e Componentes de Scripts de Terceiros](#-categoria-c-ecossistemas-e-componentes-de-scripts-de-terceiros)
5. [Guia de Contribuição: Como Sugerir Novos Pacotes](#-guia-de-contribuição-como-sugerir-novos-pacotes)

---

## 🧭 Diretrizes de Rastreabilidade e Proveniência

Para assegurar fidelidade absoluta entre a documentação e os arquivos reais do repositório, cada item instalado pelo **Fedora Multi-Shell** pertence a uma de três categorias de proveniência:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FEDORA MULTI-SHELL                              │
├───────────────────────────┬───────────────────────────┬────────────────┤
│       CATEGORIA A         │        CATEGORIA B        │  CATEGORIA C   │
│   Declarativos Fixos      │   Dinâmicos por Módulos   │ Scripts Oficiais │
│   (Pasta config/*.conf)   │   (modules/**/*.sh)       │   de Terceiros │
└───────────────────────────┴───────────────────────────┴────────────────┘
```

1. **Categoria A (Declarativos Fixos):** Mapeamento estrito (1 para 1) dos arquivos em `config/`. Nenhum pacote extra é listado nestas tabelas.
2. **Categoria B (Pacotes de Módulos):** Pacotes RPM instalados diretamente pelo orquestrador com base na escolha de hardware, compositor ou interface gráfica.
3. **Categoria C (Scripts de Terceiros):** Componentes provisionados via pipelines upstream dos próprios criadores de ecossistemas (ex: Deno, DankLinux/DMS, iNiR).

---

## 📋 Categoria A: Pacotes Declarativos Fixos (`config/`)

### 1. Pacotes Base do Sistema (`config/packages-base.conf`)

Responsáveis pela sustentação de hardware, barramentos de sistema, subsistemas de áudio e rede, portais universais, impressão e segurança:

| Pacote | Função e Justificativa Técnica |
| :--- | :--- |
| `@hardware-support` | Meta-grupo de pacotes oficial do Fedora fornecendo firmwares de suporte universal para processadores e chipsets (Intel, AMD, Realtek, Broadcom, MediaTek). |
| `open-vm-tools` | Módulos e daemons de integração para Máquinas Virtuais (VMware, VirtualBox, KVM/QEMU), viabilizando redimensionamento automático de tela e sincronização de área de transferência. |
| `python3.12` | Interpretador Python na versão compatível com a suíte de scripts de automação e integração de desktop. |
| `python3.12-devel` | Cabeçalhos e bibliotecas de desenvolvimento do Python 3.12, necessários para compilar extensões nativas em C/Rust. |
| `cairo-devel` | Arquivos de desenvolvimento da biblioteca gráfica de renderização vetorial 2D Cairo. |
| `cairo-gobject-devel` | Integração da biblioteca Cairo com o sistema de objetos GObject do ecossistema GNOME/GTK. |
| `gobject-introspection-devel` | Metadados e cabeçalhos para geração de bindings dinâmicos de linguagens para bibliotecas baseadas em GObject (essencial para scripts de shell e widgets). |
| `unzip` | Utilitário CLI para extração de arquivos compactados no formato ZIP. |
| `socat` | Utilitário de retransmissão bidirecional de sockets de rede e Unix domain sockets, utilizado na comunicação entre scripts e compositores Wayland. |
| `mpv` | Reprodutor de mídia leve e motor de reprodução por linha de comando com aceleração de hardware. |
| `tuned` | Daemon de monitoramento adaptativo do sistema e aplicação de perfis dinâmicos de otimização de CPU/disco. |
| `tuned-ppd` | Camada de tradução que implementa a API D-Bus do `power-profiles-daemon` sobre o motor do `tuned`, permitindo que shells Wayland alternem modos de energia nativamente. |
| `upower` | Daemon de abstração para gerenciamento e monitoramento de baterias de laptops e periféricos sem fio. |
| `brightnessctl` | Utilitário leve de controle de brilho de telas, painéis e retroiluminação de teclados sem necessidade de privilégios de root. |
| `libinput` | Biblioteca padrão do subsistema Linux para processamento de eventos de entrada (mouses, teclados, touchpads e touchscreens). |
| `libinput-utils` | Conjunto de ferramentas de diagnóstico e calibração de dispositivos de entrada gerenciados pela libinput. |
| `pipewire` | Servidor gráfico e multimídia moderno de processamento de áudio e vídeo de baixíssima latência. |
| `wireplumber` | Gerenciador de sessão modular e orquestrador de políticas de conexão de endpoints do PipeWire. |
| `pipewire-pulseaudio` | Servidor de compatibilidade que substitui o PulseAudio tradicional sem quebrar aplicações legadas. |
| `pipewire-alsa` | Plugin de redirecionamento transparente de chamadas ALSA para o subsistema PipeWire. |
| `NetworkManager-wifi` | Módulo de gerenciamento de interfaces e conexões de rede sem fio (Wi-Fi) no NetworkManager. |
| `wpa_supplicant` | Daemon de autenticação e negociação de chaves para redes protegidas por WPA, WPA2 e WPA3 Enterprise/Personal. |
| `bluez` | Pilha de protocolos oficial de Bluetooth para Linux. |
| `bluez-tools` | Utilitários de linha de comando para configuração, pareamento e diagnóstico de adaptadores e dispositivos Bluetooth. |
| `dbus-broker` | Implementação moderna, paralela e de alta performance do barramento de mensagens D-Bus. |
| `seatd` | Daemon leve para gerenciamento de permissões de assento gráfico (_seat management_) para sessões Wayland puras. |
| `sddm` | Display Manager e tela de login gráfico moderna baseada em Qt/QML (utilizada como opção padrão na interface iNiR). |
| `udisks2` | Serviço D-Bus para gerenciamento de operações de armazenamento em bloco, partições e montagem automática de mídias removíveis. |
| `ntfs-3g` | Driver de sistema de arquivos em espaço de usuário (FUSE) para leitura e escrita estável em partições NTFS (Windows). |
| `polkit` | Framework de autorização e controle de privilégios de granularidade fina para processos não privilegiados. |
| `gnome-keyring` | Serviço de armazenamento seguro de chaves SSH, certificados e senhas de aplicações (chaveiro GNOME). |
| `gnome-keyring-pam` | Módulo PAM que realiza o desbloqueio automático do chaveiro do usuário sincronizado à autenticação no login. |
| `libsecret` | Biblioteca cliente GObject para acessar e consultar itens protegidos no serviço Secret Service API / gnome-keyring. |
| `xdg-desktop-portal` | Barramento central de portais de desktop universais para isolamento de aplicações, compartilhamento de tela e seleção de arquivos. |
| `xdg-desktop-portal-gtk` | Implementação do portal XDG voltada a ambientes baseados em GTK e diálogos visuais universais. |
| `xdg-desktop-portal-gnome` | Implementação do portal GNOME exigida para captura de tela e ScreenCast via PipeWire no compositor Niri. |
| `xdg-user-dirs` | Utilitário para padronização e criação localizada dos diretórios especiais do usuário (`Downloads`, `Documentos`, `Música`, etc.). |
| `xdg-utils` | Conjunto de ferramentas de linha de comando para integração ao ambiente desktop (`xdg-open`, `xdg-mime`, etc.). |
| `switcheroo-control` | Serviço D-Bus para acoplamento dinâmico e alternância de renderização em arquiteturas com placas gráficas híbridas (PRIME). |
| `@printing` | Grupo de pacotes de infraestrutura de impressão do Fedora, instalando o servidor CUPS e filtros base. |
| `cups-browsed` | Daemon para descoberta automática de impressoras compartilhadas via rede local. |
| `ipp-usb` | Daemon de comunicação IPP-over-USB que permite impressão e digitalização sem instalação de drivers manuais (_Driverless_). |
| `hplip` | Drivers e ferramentas de suporte oficial para impressoras e multifuncionais da HP. |
| `printer-driver-brlaser` | Driver de código aberto otimizado para impressoras monocromáticas a laser da marca Brother. |
| `system-config-printer-udev` | Regras udev e acionadores de configuração automática ao plugar impressoras via conexão USB física. |
| `avahi` | Implementação do padrão mDNS/DNS-SD (ZeroConf/Bonjour) para descoberta instantânea de impressoras e nós de rede local. |
| `sane-backends` | Backends e bibliotecas centrais de comunicação com scanners e multifuncionais. |
| `sane-airscan` | Driver SANE universal para digitalização em rede sem driver via protocolos eSCL (Apple AirScan) e WSD (Microsoft). |
| `flatpak` | Sistema universal de empacotamento, distribuição e sandbox de aplicações para Linux. |
| `dnf-plugins-core` | Conjunto de plugins essenciais do gerenciador DNF para manuseio avançado de repositórios, compilações e COPRs. |

---

### 2. Aplicações de Usuário e Multimídia (`config/packages-apps.conf`)

Aplicações essenciais, utilitários visuais, suíte tipográfica e codecs com decodificação por hardware:

| Pacote | Função e Justificativa Técnica |
| :--- | :--- |
| `kitty` | Emulador de terminal acelerado por GPU via OpenGL, altamente configurável, com suporte nativo a protocolos gráficos de imagens e baixíssima latência. |
| `fastfetch` | Utilitário CLI moderno e de execução ultrarrápida escrito em C para visualização dos dados da máquina e distribuição. |
| `nautilus` | Gerenciador de arquivos gráfico oficial do GNOME, baseado em GTK4 e libadwaita. |
| `gvfs-mtp` | Módulo GVFS para acesso a pastas e arquivos de smartphones e dispositivos portáteis via protocolo MTP. |
| `gvfs-smb` | Backend do GVFS para montagem e acesso a compartilhamentos de rede SMB/CIFS (Windows e servidores Samba). |
| `gvfs-archive` | Módulo para navegação transparente dentro de arquivos compactados (`.zip`, `.tar`, etc.) como pastas no Nautilus. |
| `gvfs-fuse` | Ponte FUSE que exporta os pontos de montagem virtuais do GVFS para utilitários comuns de linha de comando. |
| `gnome-software` | Central gráfica de aplicativos com suporte ao catálogo Flatpak/Flathub e atualizações seguras de sistema. |
| `loupe` | Visualizador de imagens moderno do ecossistema GNOME construído em GTK4 e Rust, com suporte a gestos multitouch. |
| `papers` | Leitor e visualizador de documentos e PDFs moderno do GNOME (sucessor otimizado do Evince em GTK4). |
| `gnome-text-editor` | Editor de texto gráfico moderno com suporte a temas dinâmicos, salvamento automático e realce de sintaxe. |
| `simple-scan` | Aplicativo gráfico simples e ágil para digitalização de documentos e fotos a partir de scanners. |
| `gnome-disk-utility` | Utilitário gráfico para particionamento, formatação, inspeção de integridade S.M.A.R.T. e montagem de discos. |
| `p7zip` | Port do utilitário 7-Zip para sistemas POSIX, oferecendo suporte nativo ao formato de compressão `.7z`. |
| `p7zip-plugins` | Extensões adicionais para o `p7zip`, ampliando a compatibilidade de formatos e integrações com o gerenciador de arquivos. |
| `unrar` | Utilitário oficial para descompressão de arquivos empacotados sob o formato proprietário RAR. |
| `zstd` | Algoritmo de compressão de dados em tempo real com taxas de compressão ultrarrápidas desenvolvido pela Meta. |
| `tar` | Utilitário padrão do ecossistema Unix para arquivamento e concatenação de árvores de diretórios. |
| `xz` | Utilitário e biblioteca de compressão de dados baseada no algoritmo LZMA com alta taxa de redução de tamanho. |
| `swaylock` | Bloqueador de tela minimalista e seguro projetado para compositores Wayland com protocolo `ext-session-lock-v1`. |
| `grim` | Ferramenta de linha de comando para captura de frames e screenshots em compositores Wayland. |
| `slurp` | Utilitário interativo para seleção de áreas retangulares na tela via mouse em sessões Wayland. |
| `wl-clipboard` | Utilitários de área de transferência (`wl-copy` e `wl-paste`) para gerenciamento de clipboard Wayland nativo. |
| `playerctl` | Utilitário de terminal para inspeção e controle de reprodutores de mídia compatíveis com a especificação MPRIS D-Bus. |
| `matugen` | Gerador e extrator de paletas de cores dinâmicas Material You a partir de papéis de parede para estilização do sistema. |
| `adwaita-icon-theme` | Conjunto padrão de ícones da interface Adwaita/GNOME, garantindo visual consistente nas aplicações GTK. |
| `google-noto-sans-fonts` | Família tipográfica universal Noto Sans cobrindo todo o conjunto de caracteres latinos e ocidentais. |
| `google-noto-serif-fonts` | Família tipográfica Noto Serif para renderização clássica com serifa. |
| `google-noto-sans-cjk-fonts` | Cobertura tipográfica completa para ideogramas CJK (Chinês, Japonês e Coreano). |
| `google-noto-color-emoji-fonts` | Pacote oficial de glifos e emojis coloridos modernos do Google. |
| `glycin-thumbnailer` | Gerador isolado em sandbox de miniaturas de imagens para o Nautilus desenvolvido em Rust. |
| `ffmpegthumbnailer` | Gerador de miniaturas leves para arquivos e contêineres de vídeo (`.mp4`, `.mkv`, etc.). |
| `papers-thumbnailer` | Gerador de miniaturas para visualização prévia da capa de arquivos e documentos PDF. |
| `ffmpeg` | Pacote multimídia completo com codecs proprietários ativados via RPM Fusion (substitui a versão limitada `ffmpeg-free`). |
| `gstreamer1-plugins-bad-freeworld` | Plugins do GStreamer para suporte a formatos de áudio e vídeo de uso restrito por patentes. |
| `gstreamer1-plugins-ugly` | Plugins de codecs de alta qualidade mantidos pelo RPM Fusion sob restrições de licença. |
| `mesa-va-drivers-freeworld` | Drivers VA-API completos da Mesa com aceleração por hardware para decodificação e codificação em GPUs Intel e AMD. |

---

### 3. Drivers Proprietários NVIDIA (`config/packages-nvidia.conf`)

Pacotes provisionados exclusivamente em instalações físicas com GPU dedicada NVIDIA selecionadas pelo usuário:

| Pacote | Função e Justificativa Técnica |
| :--- | :--- |
| `kernel-devel` | Arquivos de desenvolvimento e headers do kernel correspondentes à versão exata do kernel em execução. |
| `kernel-headers` | Arquivos de cabeçalho C da API do kernel Linux para compilação de módulos de terceiros. |
| `akmods` | Sistema automatizado do Fedora/RPM Fusion que compila e gera pacotes RPM de módulos de kernel locais sob demanda. |
| `akmod-nvidia` | Driver oficial binário proprietário da NVIDIA gerenciado pelo sistema de compilação automática do `akmods`. |
| `xorg-x11-drv-nvidia-cuda` | Bibliotecas de runtime do CUDA para execução de tarefas de computação acelerada por GPU e inteligência artificial. |
| `xorg-x11-drv-nvidia-power` | Serviços systemd que gerenciam estados de energia RTD3 (Dynamic Power Management) e suspensão segura de notebooks. |
| `libva-nvidia-driver` | Ponte de tradução que expõe o motor NVDEC da NVIDIA para a interface padrão de aceleração de vídeo VA-API. |

---

### 4. Aplicações Flatpak do Flathub (`config/packages-flatpak.conf`)

Aplicações isoladas em contêiner gerenciadas via Flathub:

| Identificador do Aplicativo | Descrição e Finalidade |
| :--- | :--- |
| `io.github.diegopvlk.Cine` | Reprodutor de streaming e vídeos desktop moderno com interface polida em GTK4/libadwaita (com permissão de sistema `--filesystem=home` aplicada automaticamente). |

---

## ⚙️ Categoria B: Pacotes Oficiais Instalados por Módulos (`modules/*.sh`)

Diferente dos pacotes estáticos listados em `config/`, os pacotes desta seção são provisionados **dinamicamente** via comandos diretos `sudo dnf install` nos módulos bash conforme o fluxo e escolhas do usuário no menu interativo:

| Pacote DNF | Script Responsável | Condição de Instalação | Finalidade Técnica |
| :--- | :--- | :--- | :--- |
| `brave-browser` | `modules/03_desktop_apps.sh` | Sempre executado no Módulo 03 | Navegador focado em privacidade; instalado via repositório DNF oficial da Brave Software ou por script de contingência. |
| `greetd` | `modules/04_display_stack.sh` | Quando a interface for **Noctalia** ou **DankLinux** | Daemon minimalista e modular de login gráfico em Wayland/Console. |
| `greetd-selinux` | `modules/04_display_stack.sh` | Quando a interface for **Noctalia** ou **DankLinux** | Políticas de segurança e contextos SELinux para o daemon `greetd`. |
| `niri` | `modules/compositors/niri.sh` | Quando o compositor selecionado for **Niri** | Compositor Wayland scrollable-tiling em Rust (via COPR oficial `yalter/niri`). |
| `xwayland-satellite` | `modules/compositors/niri.sh`, `modules/compositors/umbriel.sh` | Ao instalar **Niri** ou **Umbriel** | Gerenciador de janelas X11 isolado e rootless sob demanda para rodar jogos/aplicações legadas sem poluir o Wayland nativo. |
| `umbriel-nightly` | `modules/compositors/umbriel.sh` | Quando o compositor selecionado for **Umbriel** | Compositor Wayland dinâmico com modos Dwindle, Master e rolagem contínua (via Repositório Terra do Fyra Labs). |
| `xdg-desktop-portal-umbriel-nightly` | `modules/compositors/umbriel.sh` | Quando o compositor for **Umbriel** | Implementação de portais XDG específica do compositor Umbriel. |
| `noctalia` | `modules/interfaces/noctalia.sh` | Quando a interface selecionada for **Noctalia** | Desktop shell nativo completo em C++/Qt com painel, barra de status e lançadores. |
| `noctalia-greeter` | `modules/04_display_stack.sh` | Quando a interface selecionada for **Noctalia** | Tela de login gráfica em Wayland do ecossistema Noctalia acoplada ao `greetd`. |
| `quickshell` | `modules/interfaces/inir.sh` | Quando a interface selecionada for **iNiR** | Motor declarativo em C++/Qt 6 para interfaces Wayland (via COPR `errornointernet/quickshell`). |

---

## 🌐 Categoria C: Ecossistemas e Componentes de Scripts de Terceiros

> ⚠️ **Aviso de Transparência de Arquitetura:**
> Os componentes abaixo **NÃO** constam nos arquivos `.conf` da pasta `config/` e não são pacotes RPM gerenciados pelo DNF do sistema base. Eles são provisionados e mantidos diretamente pelos pipelines e scripts oficiais de seus criadores e comunidades upstream:

### 1. DankLinux / DankMaterialShell (DMS)
- **Origem:** Instalador oficial não-interativo via pipeline HTTPS:
  ```bash
  curl -fsSL https://install.danklinux.com | sh -s -- -c niri -t kitty -y --all-features
  ```
- **Script do Instalador:** `modules/interfaces/danklinux.sh`
- **Componentes Provisionados pelo `dankinstall`:**
  - `dms`: Núcleo da interface DankMaterialShell e barra _Dank Island_.
  - `dms-greeter`: Tela de login e autenticação gráfica sobre o `greetd`.
  - `danksearch`: Daemon de indexação de arquivos ultrarrápido integrado ao lançador de aplicações.
  - `dankcalendar`: Módulo de sincronização e exibição de calendário de eventos.

### 2. iNiR Desktop Shell
- **Origem:** Repositório oficial Git [snowarch/inir](https://github.com/snowarch/inir) clonado em `~/.config/inir`.
- **Script do Instalador:** `modules/interfaces/inir.sh`
- **Componentes e Runtimes Provisionados:**
  - **Runtime Deno Oficial:** O executável nativo do `deno` é obtido via release oficial do GitHub (`denoland/deno`) e instalado em `/usr/local/bin/deno` com permissões de execução para sustentar os daemons JavaScript/TypeScript do shell.
  - **Widgets e Setup iNiR:** Compilação e linking dos componentes visuais executado via `./setup install -y` diretamente sob a sessão do usuário real.

---

## 🛠️ Guia de Contribuição: Como Sugerir Novos Pacotes

Para manter o sistema limpo, previsível e fácil de auditar, siga estas etapas para submeter melhorias:

1. **Escolha o arquivo correto em `config/`:**
   - **`config/packages-base.conf`**: Para serviços de sistema, drivers abertos, portais ou daemons de hardware que devem estar presentes em **todas** as instalações.
   - **`config/packages-apps.conf`**: Para utilitários de usuário, fontes, ferramentas multimídia ou de terminal.
   - **`config/packages-nvidia.conf`**: Para componentes exclusivos do ecossistema NVIDIA proprietário.
   - **`config/packages-flatpak.conf`**: Para aplicações gráficas de usuário disponíveis no Flathub.

2. **Diretrizes de Compatibilidade:**
   - O pacote deve ser compatível com arquitetura **100% Wayland**.
   - Evite adicionar ferramentas gráficas com dependências pesadas legadas do X11 sem necessidade estrita.
   - Mantenha a ordenação e os comentários de agrupamento temático existentes nos arquivos `.conf`.

3. **Submissão via Pull Request:**
   - Abra um Pull Request detalhando a motivação do pacote e os testes executados em máquina real ou virtual.
