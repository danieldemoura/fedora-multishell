# 📦 Catálogo de Pacotes e Dependências do Sistema

Este documento apresenta a especificação técnica completa de todos os pacotes, bibliotecas, drivers e componentes provisionados pelo projeto **Fedora Multi-Shell**.

A arquitetura do instalador opera sob rigorosa transparência técnica, modularidade em camadas e princípios estritos de **Infraestrutura como Código (IaC)**:

- **Camadas Declarativas Fixas:** Pacotes mantidos e auditáveis nos arquivos de manifesto `.conf` do diretório `config/`.
- **Serviços e Portais Dinâmicos:** Ativações de serviços de sistema, autorizações Polkit e integrações de portais acionadas defensivamente pelos módulos em `modules/` de acordo com a seleção de compositores e interfaces gráficas.
- **Ecossistemas e Componentes de Terceiros:** Runtimes, scripts upstream e suites desktop configurados por instaladores oficiais de seus respectivos mantenedores.

> 🤝 **Convite à Comunidade e Desenvolvedores:** Este catálogo foi concebido para ser 100% auditável. Sugestões de novos pacotes, atualizações de dependências e melhorias de compatibilidade Wayland puro são sempre bem-vindas via _Pull Request_.

---

## 📑 Sumário

1. [Diretrizes de Rastreabilidade e Proveniência](#-diretrizes-de-rastreabilidade-e-proveniência)
2. [Categoria A: Pacotes Declarativos Fixos (`config/packages/`)](#-categoria-a-pacotes-declarativos-fixos-configpackages)
   - [Pacotes Base do Sistema (`config/packages/base.conf`)](#1-pacotes-base-do-sistema-configpackagesbaseconf)
   - [Aplicações de Usuário e Multimídia (`config/packages/apps.conf`)](#2-aplicações-de-usuário-e-multimídia-configpackagesappsconf)
   - [Drivers Proprietários NVIDIA (`config/packages/nvidia.conf`)](#3-drivers-proprietários-nvidia-configpackagesnvidiaconf)
   - [Aplicações Flatpak do Flathub (`config/packages/flatpak.conf`)](#4-aplicações-flatpak-do-flathub-configpackagesflatpakconf)
   - [Desktop Shell iNiR (`config/packages/inir.conf`)](#5-desktop-shell-inir-configpackagesinirconf)
   - [Desktop Shell Noctalia (`config/packages/noctalia.conf`)](#6-desktop-shell-noctalia-configpackagesnoctaliaconf)
   - [Compositor Niri (`config/packages/niri.conf`)](#7-compositor-niri-configpackagesniriconf)
   - [Compositor Umbriel (`config/packages/umbriel.conf`)](#8-compositor-umbriel-configpackagesumbrielconf)
   - [Display Manager Greetd (`config/packages/greetd.conf`)](#9-display-manager-greetd-configpackagesgreetdconf)
   - [Display Manager SDDM (`config/packages/sddm.conf`)](#10-display-manager-sddm-configpackagessddmconf)
   - [Navegador Brave Browser (`config/packages/brave.conf`)](#11-navegador-brave-browser-configpackagesbraveconf)
   - [Pilha Gráfica Aberta Mesa (`config/packages/mesa.conf`)](#12-pilha-gráfica-aberta-mesa-configpackagesmesaconf)
3. [Categoria B: Serviços e Portais Dinâmicos](#-categoria-b-serviços-e-portais-dinâmicos)
4. [Categoria C: Ecossistemas e Componentes de Scripts de Terceiros](#-categoria-c-ecossistemas-e-componentes-de-scripts-de-terceiros)
5. [Guia de Contribuição: Como Sugerir Novos Pacotes](#-guia-de-contribuição-como-sugerir-novos-pacotes)

---

## 🧭 Diretrizes de Rastreabilidade e Proveniência

Para assegurar fidelidade absoluta entre a documentação e os arquivos reais do repositório, cada item instalado pelo **Fedora Multi-Shell** pertence a uma de três categorias de proveniência:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        FEDORA MULTI-SHELL                              │
├───────────────────────────┬───────────────────────────┬────────────────┤
│       CATEGORIA A         │        CATEGORIA B        │  CATEGORIA C   │
│   Declarativos Fixos      │   Serviços e Portais      │ Scripts Upstream │
│ (config/packages/*.conf)  │   Dinâmicos de Módulos    │  de Terceiros  │
└───────────────────────────┴───────────────────────────┴────────────────┘
```

1. **Categoria A (Declarativos Fixos):** Mapeamento estrito (1 para 1) dos arquivos em `config/packages/`. Nenhum pacote extra é listado nestas tabelas.
2. **Categoria B (Serviços e Portais Dinâmicos):** Serviços do systemd, permissões Polkit, integrações PAM e portais acionados pelos módulos com base no hardware ou na escolha do usuário.
3. **Categoria C (Scripts de Terceiros):** Componentes provisionados via pipelines upstream oficiais de seus criadores (ex: Deno, Dux Shell/DMS, setup do iNiR).

---

## 📋 Categoria A: Pacotes Declarativos Fixos (`config/packages/`)

### 1. Pacotes Base do Sistema (`config/packages/base.conf`)

Responsáveis pela sustentação de hardware, barramentos de sistema, subsistemas de áudio e rede, portais universais, impressão e segurança:

| Pacote                        | Função e Justificativa Técnica                                                                                                                                                     |
| :---------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@hardware-support`           | Meta-grupo de pacotes oficial do Fedora fornecendo firmwares de suporte universal para processadores e chipsets (Intel, AMD, Realtek, Broadcom, MediaTek).                         |
| `open-vm-tools`               | Módulos e daemons de integração para Máquinas Virtuais (VMware, VirtualBox, KVM/QEMU), viabilizando redimensionamento automático de tela e sincronização de área de transferência. |
| `python3`                     | Interpretador Python na versão padrão da release do Fedora (não pinada), compatível com a suíte de scripts de automação e integração de desktop.                                   |
| `python3-devel`               | Cabeçalhos e bibliotecas de desenvolvimento do Python padrão do Fedora, necessários para compilar extensões nativas em C/Rust.                                                     |
| `cairo-devel`                 | Arquivos de desenvolvimento da biblioteca gráfica de renderização vetorial 2D Cairo.                                                                                               |
| `cairo-gobject-devel`         | Integração da biblioteca Cairo com o sistema de objetos GObject do ecossistema GNOME/GTK.                                                                                          |
| `gobject-introspection-devel` | Metadados e cabeçalhos para geração de bindings dinâmicos de linguagens para bibliotecas baseadas em GObject (essencial para scripts de shell e widgets).                          |
| `unzip`                       | Utilitário CLI para extração de arquivos compactados no formato ZIP.                                                                                                               |
| `socat`                       | Utilitário de retransmissão bidirecional de sockets de rede e Unix domain sockets, utilizado na comunicação entre scripts e compositores Wayland.                                  |
| `mpv`                         | Reprodutor de mídia leve e motor de reprodução por linha de comando com aceleração de hardware.                                                                                    |
| `tuned`                       | Daemon de monitoramento adaptativo do sistema e aplicação de perfis dinâmicos de otimização de CPU/disco.                                                                          |
| `tuned-ppd`                   | Camada de tradução que implementa a API D-Bus do `power-profiles-daemon` sobre o motor do `tuned`, permitindo que shells Wayland alternem modos de energia nativamente.            |
| `upower`                      | Daemon de abstração para gerenciamento e monitoramento de baterias de laptops e periféricos sem fio.                                                                               |
| `brightnessctl`               | Utilitário leve de controle de brilho de telas, painéis e retroiluminação de teclados sem necessidade de privilégios de root.                                                      |
| `libinput`                    | Biblioteca padrão do subsistema Linux para processamento de eventos de entrada (mouses, teclados, touchpads e touchscreens).                                                       |
| `libinput-utils`              | Conjunto de ferramentas de diagnóstico e calibração de dispositivos de entrada gerenciados pela libinput.                                                                          |
| `pipewire`                    | Servidor gráfico e multimídia moderno de processamento de áudio e vídeo de baixíssima latência.                                                                                    |
| `wireplumber`                 | Gerenciador de sessão modular e orquestrador de políticas de conexão de endpoints do PipeWire.                                                                                     |
| `pipewire-pulseaudio`         | Servidor de compatibilidade que substitui o PulseAudio tradicional sem quebrar aplicações legadas.                                                                                 |
| `pipewire-alsa`               | Plugin de redirecionamento transparente de chamadas ALSA para o subsistema PipeWire.                                                                                               |
| `NetworkManager-wifi`         | Módulo de gerenciamento de interfaces e conexões de rede sem fio (Wi-Fi) no NetworkManager.                                                                                        |
| `wpa_supplicant`              | Daemon de autenticação e negociação de chaves para redes protegidas por WPA, WPA2 e WPA3 Enterprise/Personal.                                                                      |
| `bluez`                       | Pilha de protocolos oficial de Bluetooth para Linux.                                                                                                                               |
| `bluez-tools`                 | Utilitários de linha de comando para configuração, pareamento e diagnóstico de adaptadores e dispositivos Bluetooth.                                                               |
| `dbus-broker`                 | Implementação moderna, paralela e de alta performance do barramento de mensagens D-Bus.                                                                                            |
| `seatd`                       | Daemon leve para gerenciamento de permissões de assento gráfico (_seat management_) para sessões Wayland puras.                                                                    |
| `sddm`                        | Display Manager e tela de login gráfica baseada em Qt/QML.                                                                                                                         |
| `udisks2`                     | Serviço D-Bus para gerenciamento de operações de armazenamento em bloco, partições e montagem automática de mídias removíveis.                                                     |
| `ntfs-3g`                     | Driver de sistema de arquivos em espaço de usuário (FUSE) para leitura e escrita estável em partições NTFS (Windows).                                                              |
| `polkit`                      | Framework de autorização e controle de privilégios de granularidade fina para processos não privilegiados.                                                                         |
| `gnome-keyring`               | Serviço de armazenamento seguro de chaves SSH, certificados e senhas de aplicações (chaveiro GNOME).                                                                               |
| `gnome-keyring-pam`           | Módulo PAM que realiza o desbloqueio automático do chaveiro do usuário sincronizado à autenticação no login.                                                                       |
| `libsecret`                   | Biblioteca cliente GObject para acessar e consultar itens protegidos no serviço Secret Service API / gnome-keyring.                                                                |
| `xdg-desktop-portal`          | Barramento central de portais de desktop universais para isolamento de aplicações, compartilhamento de tela e seleção de arquivos.                                                 |
| `xdg-desktop-portal-gtk`      | Implementação do portal XDG voltada a ambientes baseados em GTK e diálogos visuais universais.                                                                                     |
| `xdg-desktop-portal-gnome`    | Implementação do portal GNOME exigida para captura de tela e ScreenCast via PipeWire no compositor Niri.                                                                           |
| `xdg-user-dirs`               | Utilitário para padronização e criação localizada dos diretórios especiais do usuário (`Downloads`, `Documentos`, `Música`, etc.).                                                 |
| `xdg-utils`                   | Conjunto de ferramentas de linha de comando para integração ao ambiente desktop (`xdg-open`, `xdg-mime`, etc.).                                                                    |
| `@printing`                   | Grupo de pacotes de infraestrutura de impressão do Fedora, instalando o servidor CUPS e filtros base.                                                                              |
| `cups-browsed`                | Daemon para descoberta automática de impressoras compartilhadas via rede local.                                                                                                    |
| `ipp-usb`                     | Daemon que expõe dispositivos IPP-over-USB locais como servidores HTTP na rede loopback, dispensando drivers proprietários.                                                        |
| `hplip`                       | Conjunto oficial de drivers e utilitários de impressão/digitalização da HP.                                                                                                        |
| `printer-driver-brlaser`      | Driver aberto e otimizado para impressoras laser monocromáticas da marca Brother.                                                                                                  |
| `system-config-printer-udev`  | Módulos e regras Udev para detecção plug-and-play automática e configuração de impressoras USB.                                                                                    |
| `avahi`                       | Implementação do protocolo mDNS/DNS-SD (Bonjour/ZeroConf) para descoberta de impressoras e scanners em rede.                                                                       |
| `sane-backends`               | Infraestrutura central e drivers de digitalização de imagens do Linux (SANE).                                                                                                      |
| `sane-airscan`                | Backend universal e estável de digitalização sem driver via protocolos eSCL e WSD (rede e USB).                                                                                    |
| `flatpak`                     | Sistema universal de gerenciamento de pacotes isolados (sandboxed) para desktop.                                                                                                   |
| `dnf-plugins-core`            | Conjunto de plugins fundamentais para expansão do gerenciador de pacotes DNF (`copr`, `config-manager`, etc.).                                                                     |
| `git`                         | Ferramenta de controle de versão essencial para clonagem de repositórios e gestão de código.                                                                                       |
| `curl`                        | Utilitário de linha de comando para transferência de dados e download de arquivos com sintaxe de URL (HTTP/HTTPS/FTP).                                                             |

---

### 2. Aplicações de Usuário e Multimídia (`config/packages/apps.conf`)

Conjunto essencial de ferramentas gráficas, terminal, fontes e codecs provisionados para o usuário:

| Pacote                             | Função e Justificativa Técnica                                                                                                    |
| :--------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- |
| `kitty`                            | Emulador de terminal acelerado por GPU via OpenGL, rápido, moderno e configurado como terminal padrão.                            |
| `fastfetch`                        | Utilitário CLI em C para exibição instantânea de informações de hardware, sistema e logos ASCII.                                  |
| `nautilus`                         | Gerenciador de arquivos oficial do GNOME, com interface GTK4 e integração moderna ao Wayland.                                     |
| `gvfs-mtp`                         | Módulo GVFS para montagem e transferência de arquivos em smartphones e dispositivos Android via MTP.                              |
| `gvfs-smb`                         | Suporte a compartilhamentos de rede SMB/CIFS (servidores Windows, Samba e NAS).                                                   |
| `gvfs-archive`                     | Módulo GVFS para montagem transparente de arquivos compactados (ZIP, TAR, ISO) como pastas normais no Nautilus.                   |
| `gvfs-fuse`                        | Ponte FUSE que expõe as montagens de rede e virtuais do GVFS para ferramentas de terminal tradicionais via `/run/user/$UID/gvfs`. |
| `gnome-software`                   | Loja oficial de aplicativos do Fedora com interface gráfica completa e suporte nativo ao Flathub.                                 |
| `loupe`                            | Visualizador de imagens moderno em GTK4/libadwaita com aceleração de hardware e gestos touchpad.                                  |
| `papers`                           | Leitor de documentos e arquivos PDF em GTK4 (sucessor moderno e performático do Evince).                                          |
| `gnome-text-editor`                | Editor de texto gráfico moderno e responsivo do GNOME.                                                                            |
| `simple-scan`                      | Utilitário intuitivo de digitalização de documentos e imagens integrado ao sane-airscan.                                          |
| `gnome-disk-utility`               | Utilitário gráfico completo para particionamento, formatação, teste SMART e benchmark de unidades de disco.                       |
| `p7zip`                            | Port Linux CLI da ferramenta de alta compressão 7-Zip.                                                                            |
| `p7zip-plugins`                    | Plugins estendidos para suporte a formatos de compressão avançados no p7zip.                                                      |
| `unrar`                            | Utilitário para descompressão de arquivos no formato proprietário RAR.                                                            |
| `zstd`                             | Algoritmo e utilitário CLI de compressão rápida em tempo real desenvolvido pela Meta.                                             |
| `tar`                              | Ferramenta universal Unix para criação e manipulação de arquivos tarball.                                                         |
| `xz`                               | Utilitário de compressão LZMA de alta densidade padrão do ecossistema Linux.                                                      |
| `swaylock`                         | Bloqueador de tela Wayland seguro com suporte a efeitos visuais e integração PAM.                                                 |
| `grim`                             | Utilitário CLI para captura de tela (screenshots) em compositores Wayland que implementam `wlr-screencopy`.                       |
| `slurp`                            | Utilitário para seleção interativa de regiões de tela via mouse para uso em conjunto com o `grim`.                                |
| `wl-clipboard`                     | Ferramentas de linha de comando (`wl-copy` e `wl-paste`) para manipulação da área de transferência no Wayland.                    |
| `playerctl`                        | Utilitário CLI e controlador D-Bus MPRIS para pausar, reproduzir e controlar players de áudio/vídeo via atalhos do teclado.       |
| `matugen`                          | Gerenciador de cores e temas que gera paletas harmoniosas com base no papel de parede (Material You).                             |
| `adwaita-icon-theme`               | Conjunto padrão de ícones do GNOME/GTK garantindo conformidade visual às aplicações.                                              |
| `google-noto-sans-fonts`           | Família tipográfica Sans-Serif moderna e completa do projeto Google Noto.                                                         |
| `google-noto-serif-fonts`          | Família tipográfica Serifada do projeto Google Noto.                                                                              |
| `google-noto-sans-cjk-fonts`       | Suporte tipográfico universal a caracteres CJK (Chinês, Japonês e Coreano).                                                       |
| `google-noto-color-emoji-fonts`    | Conjunto de emojis em cores de alta resolução padrão do Google/Android.                                                           |
| `glycin-thumbnailer`               | Gerador moderno de miniaturas de imagens protegido por sandbox para o Nautilus.                                                   |
| `ffmpegthumbnailer`                | Utilitário leve que extrai miniaturas de arquivos de vídeo locais para exibição no gerenciador de arquivos.                       |
| `papers-thumbnailer`               | Gerador de miniaturas da primeira página de documentos e arquivos PDF para o Nautilus.                                            |
| `ffmpeg`                           | Pacote completo e irrestrito do FFmpeg obtido do RPM Fusion (com suporte a decodificação de formatos proprietários).              |
| `gstreamer1-plugins-bad-freeworld` | Plugins GStreamer adicionais do RPM Fusion com suporte a codecs proprietários e experimentais.                                    |
| `gstreamer1-plugins-ugly`          | Conjunto de plugins GStreamer de alta qualidade com restrições de licença (MP3 legado, MPEG, etc.).                               |
| `mesa-va-drivers-freeworld`        | Drivers VA-API da Mesa com suporte nativo completo a aceleração por hardware para decodificação H.264, H.265 e VC-1.              |

---

### 3. Drivers Proprietários NVIDIA (`config/packages/nvidia.conf`)

Pacotes provisionados exclusivamente em instalações físicas com GPU dedicada NVIDIA selecionadas pelo usuário:

| Pacote                      | Função e Justificativa Técnica                                                                                     |
| :-------------------------- | :----------------------------------------------------------------------------------------------------------------- |
| `kernel-devel`              | Arquivos de desenvolvimento e headers do kernel correspondentes à versão exata do kernel em execução.              |
| `kernel-headers`            | Arquivos de cabeçalho C da API do kernel Linux para compilação de módulos de terceiros.                            |
| `akmods`                    | Sistema automatizado do Fedora/RPM Fusion que compila e gera pacotes RPM de módulos de kernel locais sob demanda.  |
| `akmod-nvidia`              | Driver oficial binário proprietário da NVIDIA gerenciado pelo sistema de compilação automática do `akmods`.        |
| `xorg-x11-drv-nvidia-cuda`  | Bibliotecas de runtime do CUDA para execução de tarefas de computação acelerada por GPU e inteligência artificial. |
| `xorg-x11-drv-nvidia-power` | Serviços systemd que gerenciam estados de energia RTD3 (Dynamic Power Management) e suspensão segura de notebooks. |
| `libva-nvidia-driver`       | Ponte de tradução que expõe o motor NVDEC da NVIDIA para a interface padrão de aceleração de vídeo VA-API.         |

---

### 4. Aplicações Flatpak do Flathub (`config/packages/flatpak.conf`)

Aplicações isoladas em contêiner gerenciadas via Flathub:

| Identificador do Aplicativo | Descrição e Finalidade                                                                                                                                            |
| :-------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `io.github.diegopvlk.Cine`  | Reprodutor de streaming e vídeos desktop moderno com interface polida em GTK4/libadwaita (com permissão de sistema `--filesystem=home` aplicada automaticamente). |

---

### 5. Desktop Shell iNiR (`config/packages/inir.conf`)

Dependências declarativas, runtimes QML e módulos de efeitos da interface iNiR:

| Pacote                    | Função e Justificativa Técnica                                                                                                          |
| :------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------- |
| `quickshell`              | Framework e motor declarativo em C++/Qt 6 para construção de interfaces Wayland personalizadas (via COPR `errornointernet/quickshell`). |
| `qt6-qtdeclarative`       | Runtime do Qt 6 e motor de execução para aplicações baseadas em QML.                                                                    |
| `qt6-qtdeclarative-devel` | Cabeçalhos e arquivos de compilação para extensões declarativas em QML do Qt 6.                                                         |
| `qt6-qt5compat`           | Módulos gráficos de compatibilidade do Qt 6 exigidos pelos shaders e efeitos visuais do tema Iris.                                      |
| `qt6-qt5compat-devel`     | Cabeçalhos e arquivos de desenvolvimento da camada Qt 5 Compat do Qt 6.                                                                 |
| `qt6-qtsvg`               | Biblioteca de renderização vetorial SVG para ícones e elementos do Qt 6.                                                                |
| `qt6-qtwayland`           | Módulo de suporte e protocolos nativos Wayland para clientes Qt 6.                                                                      |

---

### 6. Desktop Shell Noctalia (`config/packages/noctalia.conf`)

Pacotes nativos da interface desktop Noctalia e sua tela de login:

| Pacote             | Função e Justificativa Técnica                                                                                          |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------- |
| `noctalia`         | Desktop shell nativo completo em C++/Qt com painel, barra de status e lançadores.                                       |
| `noctalia-greeter` | Tela de login gráfica em Wayland acoplada ao Greetd com suporte a sincronização de papéis de parede e temas via Polkit. |

---

### 7. Compositor Niri (`config/packages/niri.conf`)

Componentes declarativos do compositor Wayland Niri:

| Pacote                     | Função e Justificativa Técnica                                                                                                          |
| :------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------- |
| `niri`                     | Compositor Wayland scrollable-tiling de alta performance com rolagem horizontal contínua de colunas e janelas (via COPR `yalter/niri`). |
| `xwayland-satellite`       | Gerenciador X11 rootless e isolado sob demanda para suporte a janelas legadas.                                                          |
| `xdg-desktop-portal-gnome` | Implementação do portal GNOME exigida para compartilhamento de tela e captura via PipeWire no Niri.                                     |
| `xdg-desktop-portal-gtk`   | Implementação do portal GTK para compatibilidade de janelas de diálogo e temas.                                                         |

---

### 8. Compositor Umbriel (`config/packages/umbriel.conf`)

Dependências exclusivas para o provisionamento do compositor Wayland dinâmico Umbriel:

| Pacote                               | Função e Justificativa Técnica                                                                                                                 |
| :----------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| `umbriel-nightly`                    | Compositor Wayland dinâmico com suporte a rolagem contínua e múltiplos modos de mosaico (Dwindle e Master) via Repositório Terra do Fyra Labs. |
| `xwayland-satellite`                 | Gerenciador X11 rootless e isolado sob demanda para suporte a janelas legadas.                                                                 |
| `xdg-desktop-portal-umbriel-nightly` | Implementação oficial de portais XDG específica do compositor Umbriel.                                                                         |
| `xdg-desktop-portal-gtk`             | Implementação do portal GTK para compatibilidade universal de janelas de diálogo e temas.                                                      |

---

### 9. Display Manager Greetd (`config/packages/greetd.conf`)

Componentes declarativos da pilha de login leve Greetd:

| Pacote              | Função e Justificativa Técnica                                                         |
| :------------------ | :------------------------------------------------------------------------------------- |
| `greetd`            | Daemon minimalista e modular de login gráfico em Wayland/Console.                      |
| `greetd-selinux`    | Políticas de segurança e contextos SELinux para o daemon `greetd`.                     |
| `gnome-keyring-pam` | Módulo PAM para desbloqueio automático do cofre de credenciais GNOME Keyring no login. |

---

### 10. Display Manager SDDM (`config/packages/sddm.conf`)

Componentes declarativos da pilha de login SDDM:

| Pacote              | Função e Justificativa Técnica                                                         |
| :------------------ | :------------------------------------------------------------------------------------- |
| `sddm`              | Display Manager oficial baseado em QML e Wayland.                                      |
| `gnome-keyring-pam` | Módulo PAM para desbloqueio automático do cofre de credenciais GNOME Keyring no login. |

---

### 11. Navegador Brave Browser (`config/packages/brave.conf`)

Manifesto de instalação declarativa do navegador web principal:

| Pacote         | Função e Justificativa Técnica                                                                                                                      |
| :------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------- |
| `brave-origin` | Versão oficial do Brave Browser focada em privacidade e performance, desprovida de telemetria invasiva, IA desnecessária e módulos de criptomoedas. |

---

### 12. Pilha Gráfica Aberta Mesa (`config/packages/mesa.conf`)

Aceleração gráfica aberta (Intel/AMD/Nouveau) provisionada pelo Módulo 02. Em Máquinas Virtuais, a instalação é restrita à base DRI/Vulkan com `--exclude=switcheroo-control --exclude=mesa-va-drivers-freeworld`:

| Pacote                      | Função e Justificativa Técnica                                                                                |
| :-------------------------- | :------------------------------------------------------------------------------------------------------------ |
| `mesa-dri-drivers`          | Conjuntos de drivers DRI de código aberto para renderização OpenGL em Intel, AMD (Radeon) e NVIDIA (Nouveau). |
| `mesa-vulkan-drivers`       | Drivers Vulkan da mesa RADV (AMD) e ANV/Intel para renderização gráfica de baixa sobrecarga.                  |
| `mesa-va-drivers-freeworld` | Drivers VA-API da Mesa com decodificação por hardware habilitada para H.264, H.265 e VC-1 (RPM Fusion).       |
| `libva-utils`               | Utilitários de diagnóstico (`vainfo`) para inspecionar entrypoints e perfis VA-API disponíveis.               |
| `switcheroo-control`        | Serviço D-Bus para hibridação e alternância dinâmica de GPU (PRIME) em laptops com duas placas de vídeo.      |

---

## ⚙️ Categoria B: Serviços e Portais Dinâmicos

Os itens desta seção não são pacotes avulsos com nomes fixos em scripts procedurais, mas serviços, regras de sistema e configurações ativadas dinamicamente:

| Componente / Recurso                                          | Script Responsável              | Condição de Ativação                        | Finalidade Técnica                                                                                  |
| :------------------------------------------------------------ | :------------------------------ | :------------------------------------------ | :-------------------------------------------------------------------------------------------------- |
| Microcódigo de CPU (`intel-microcode` / `amd-ucode-firmware`) | `modules/01_system_hardware.sh` | Conforme detecção de CPU em `/proc/cpuinfo` | Atualização de microcódigo de segurança e estabilidade da CPU.                                      |
| `noctalia-greeter passwordless-sync`                          | `modules/04_display_stack.sh`   | Quando a interface for Noctalia             | Regra Polkit para sincronização bidirecional de papéis de parede entre o desktop e a tela de login. |
| Integração PAM Keyring (`pam_gnome_keyring.so`)               | `modules/04_display_stack.sh`   | Em todas as sessões gráficas (Greetd/SDDM)  | Previne pop-ups de desbloqueio de senhas no Brave e aplicativos de sistema.                         |
| Prioridades XDG (`niri-portals.conf`)                         | `modules/compositors/niri.sh`   | Quando o compositor for Niri                | Define prioridades `gtk;gnome;` para ScreenCast e Screenshot sem conflitos.                         |
| Software Rendering VM Flags                                   | `modules/07_post_install.sh`    | Quando executado em VM (`IS_VM=true`)       | Injeção defensiva de flags OpenGL de software prevenindo telas pretas no QtQuick/Wayland.           |

---

## 🌐 Categoria C: Ecossistemas e Componentes de Scripts de Terceiros

> ⚠️ **Aviso de Transparência de Arquitetura:**
> Os componentes abaixo **NÃO** constam nos arquivos `.conf` da pasta `config/` como pacotes RPM do sistema base. Eles são provisionados e mantidos diretamente pelos pipelines e scripts oficiais de seus criadores upstream:

### 1. Dux Shell (DMS) — anteriormente DankLinux / DankMaterialShell

- **Origem:** Instalador oficial não-interativo via pipeline HTTPS (URL nova do rebrand 2.0 da Dux Labs):
  ```bash
  curl -fsSL https://install.duxlabs.dev | sh -s -- -c niri -t kitty -y --all-features
  ```
- **Script do Instalador:** `modules/interfaces/duxshell.sh`
- **Componentes Provisionados pelo instalador da Dux Labs (binário `dankinstall`):**
  - `dms`: Núcleo da interface Dux Shell e barra _Dank Island_.
  - `dms-greeter`: Tela de login e autenticação gráfica sobre o `greetd` (produto "Dux Greeter").
  - `danksearch`: Daemon de indexação de arquivos ultrarrápido integrado ao lançador de aplicações (produto "Dux Search").
  - `dankcalendar`: Módulo de sincronização e exibição de calendário de eventos (produto "Dux Calendar").

> ℹ️ **Nota de nomenclatura (release 2.0):** A suíte foi renomeada para **Dux Labs** e o shell para **Dux Shell**, mas os nomes de pacotes RPM/binários permanecem `dms`, `dms-greeter`, `danksearch` e `dankcalendar` — e o repositório Fedora ativo continua o COPR `avengemedia/danklinux`, pois os COPRs `duxlabs/*` ainda não estão prontos para produção segundo o aviso oficial dos mantenedores.

### 2. iNiR Desktop Shell

- **Origem:** Repositório oficial Git `snowarch/inir` clonado em `~/.config/inir`.
- **Script do Instalador:** `modules/interfaces/inir.sh`
- **Componentes e Runtimes Provisionados:**
  - **Runtime Deno Oficial:** O executável nativo do `deno` é obtido via release oficial do GitHub (`denoland/deno`), com alvo de arquitetura detectado por `uname -m` (x86_64/aarch64) e **verificação de integridade via checksum SHA-256** publicado na própria release antes da instalação em `/usr/local/bin/deno`, sustentando os daemons JavaScript/TypeScript do shell.
  - **Widgets e Setup iNiR:** Compilação e linking dos componentes visuais executado via `./setup install -y` diretamente sob a sessão do usuário real.

---

## 🛠️ Guia de Contribuição: Como Sugerir Novos Pacotes

Para manter o sistema limpo, previsível e fácil de auditar, siga estas etapas para submeter melhorias:

1. **Escolha o arquivo correto em `config/`:**
   - `config/packages/base.conf`: Para serviços de sistema, drivers abertos, portais ou daemons de hardware que devem estar presentes em **todas** as instalações.
   - `config/packages/apps.conf`: Para utilitários de usuário, fontes, ferramentas multimídia ou de terminal.
   - `config/packages/niri.conf`: Para pacotes específicos do compositor Niri.
   - `config/packages/umbriel.conf`: Para pacotes específicos do compositor Umbriel.
   - `config/packages/inir.conf`: Para pacotes RPM específicos da interface iNiR.
   - `config/packages/noctalia.conf`: Para pacotes RPM específicos da interface Noctalia.
   - `config/packages/greetd.conf`: Para componentes base do Display Manager Greetd.
   - `config/packages/sddm.conf`: Para componentes base do Display Manager SDDM.
   - `config/packages/brave.conf`: Para manifesto do navegador Brave Browser.
   - `config/packages/mesa.conf`: Para drivers e utilitários da pilha gráfica aberta Mesa (DRI/Vulkan/VA-API/PRIME).
   - `config/packages/nvidia.conf`: Para componentes exclusivos do ecossistema NVIDIA proprietário.
   - `config/packages/flatpak.conf`: Para aplicações gráficas de usuário disponíveis no Flathub.

2. **Diretrizes de Compatibilidade:**
   - O pacote deve ser compatível com arquitetura **100% Wayland**.
   - Evite adicionar ferramentas gráficas com dependências pesadas legadas do X11 sem necessidade estrita.
   - Mantenha a ordenação e os comentários de agrupamento temático existentes nos arquivos `.conf`.

3. **Submissão via Pull Request:**
   - Abra um Pull Request detalhando a motivação do pacote e os testes executados em máquina real ou virtual.
