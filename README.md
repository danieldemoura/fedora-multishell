# 🌌 Fedora Multi-Shell: Ambientes Wayland Modernos

<div align="center">

![Google Antigravity](https://img.shields.io/badge/IDE-Google%20Antigravity-4285F4?style=flat-square&logo=google&logoColor=white)
![Gemini 3.8 Flash](https://img.shields.io/badge/Model-Gemini%203.8%20Flash-8E75C2?style=flat-square&logo=googlegemini&logoColor=white)
![Google Free Tier](https://img.shields.io/badge/Tier-Google%20Free%20Plan-0F9D58?style=flat-square)
![Agentic Workflow](https://img.shields.io/badge/Workflow-Agentic%20AI-orange?style=flat-square)

</div>

### Transforme o Fedora Everything em uma instalação completa e com interface gráfica moderna.

> 💡 **Transparência Técnica & Engenharia:** Este projeto foi concebido e homologado pelo autor utilizando o **Antigravity IDE** e o modelo **Gemini 3.8 Flash** (plano gratuito da Google) em fluxo agêntico autônomo.

> 📋 **Documento de Arquitetura Base:** Todo o projeto foi planejado e executado com base no [Plano de Implementação e Especificação Técnica](docs/PLANO_DE_IMPLEMENTAÇÃO_E_ESPECIFICAÇÃO_TÉCNICA.md). Esse arquivo contém todas as diretrizes de arquitetura em camadas, tratamento defensivo do PAM/Keyring, suporte a máquinas virtuais e decisões de projeto utilizadas pela IA para construir o instalador.
> 
> Consulte o [Catálogo de Pacotes e Dependências](docs/CATALOGO_DE_PACOTES.md) para ver a listagem completa e detalhada de tudo o que é provisionado pelo sistema e as [Diretrizes de Arquitetura e Boas Práticas](docs/DIRETRIZES_DE_ARQUITETURA_E_BOAS_PRATICAS.md) para os padrões de engenharia e regras de programação defensiva adotadas.

Instalador modular, em camadas e automatizado para transformar uma instalação mínima do **Fedora Everything Netinstall** em uma workstation gráfica moderna com suporte à seleção exclusiva de **Interface Gráfica (Desktop Shell)** e **Compositor Wayland**:

- **Interfaces Gráficas (Desktop Interfaces):**
  - **iNiR Shell:** Interface moderna baseada em Quickshell, C++/Qt e theming dinâmico Material You via COPR `errornointernet/quickshell` (utiliza exclusivamente o compositor Niri).
  - **Noctalia Shell:** Interface gráfica desktop nativa em C++/Qt via pacote nativo Fedora (permite escolher entre o compositor Niri ou Umbriel).
  - **DankMaterialShell / DMS (DankLinux):** Interface gráfica e ambiente completo DankLinux via COPR `avengemedia/danklinux` e instalador oficial headless `dankinstall` (utiliza Niri, terminal Kitty, `dms-greeter`, `danksearch` e `dankcalendar`).
- **Compositores Wayland de Alta Performance:**
  - **Niri:** Scrollable tiling Wayland compositor com rolagem horizontal contínua de colunas via COPR `yalter/niri`.
  - **Umbriel:** Compositor Wayland dinâmico via Repositório Terra do Fyra Labs, com suporte à rolagem contínua de janelas (horizontal e vertical), além de múltiplos modos de exibição dinâmicos (Dwindle e Master).
- **Display Manager / Gerenciador de Login:** [SDDM](https://github.com/sddm/sddm) nativo ou [Greetd](https://git.sr.ht/~kennylevinsen/greetd) (`noctalia-greeter` / `dms-greeter`) com integração e desbloqueio silencioso do PAM GNOME Keyring.
- **Emulador de Terminal & CLI:** [Kitty](https://sw.kovidgoyal.net/kitty/) (acelerado por GPU) + `fastfetch` (resumo de hardware).
- **Compatibilidade X11:** `xwayland-satellite` (rootless isolado).
- **Navegador Web:** Brave Origin (sem telemetria, IA ou criptomoedas).
- **Loja de Apps:** GNOME Software (Loja gráfica nativa com integração ao Flathub e atualizações de sistema).
- **Reprodutor de Vídeo:** Cine (`io.github.diegopvlk.Cine` via Flatpak).
- **Documentação Técnica:** Consulte o [Plano de Implementação e Especificação Técnica](docs/PLANO_DE_IMPLEMENTAÇÃO_E_ESPECIFICAÇÃO_TÉCNICA.md).

---

## 🏗️ Arquitetura em Camadas (Layered Architecture)

O projeto adota os princípios de **Separação de Preocupações (SoC)**, **Idempotência**, **Infraestrutura como Código (IaC)** e **Padrão Strategy** para despachar submódulos de compositores e interfaces gráficas. Os pacotes de usuário (fontes, terminal Kitty e codecs) são instalados no Módulo 03, garantindo ambiente pronto antes de subir a stack visual:

```text
fedora-multishell/
├── install.sh                       # Ponto de entrada: validações, menu interativo pt-BR e orquestrador
├── docs/
│   ├── PLANO_DE_IMPLEMENTAÇÃO_E_ESPECIFICAÇÃO_TÉCNICA.md # Especificação técnica completa
│   ├── CATALOGO_DE_PACOTES.md       # Catálogo detalhado e mapeamento de dependências
│   └── DIRETRIZES_DE_ARQUITETURA_E_BOAS_PRATICAS.md # Regras de engenharia e boas práticas
├── config/
│   ├── settings.conf                # Variáveis globais, repositórios e flags padrão
│   ├── packages/                    # Manifestos declarativos de pacotes (DNF / Flatpak)
│   │   ├── apps.conf                # Aplicações universais de usuário (Kitty, Nautilus, Codecs)
│   │   ├── base.conf                # Infraestrutura base do sistema (Hardware, Som, Rede, VM)
│   │   ├── brave.conf               # Manifesto de instalação do navegador Brave Browser
│   │   ├── flatpak.conf             # Lista declarativa de aplicativos Flatpak do Flathub (com overrides)
│   │   ├── greetd.conf              # Daemons base do Display Manager Greetd
│   │   ├── inir.conf                # Dependências, runtimes e shaders do iNiR / Iris / Quickshell
│   │   ├── mesa.conf                # Pilha gráfica aberta Mesa (DRI/Vulkan/VA-API/PRIME)
│   │   ├── niri.conf                # Pacotes do compositor Niri, xwayland-satellite e portais
│   │   ├── noctalia.conf            # Pacotes nativos da interface Noctalia e Greeter
│   │   ├── nvidia.conf              # Pilha proprietária de drivers e módulos NVIDIA (akmods)
│   │   ├── sddm.conf                # Pacotes base do Display Manager SDDM
│   │   └── umbriel.conf             # Pacotes do compositor Umbriel Nightly e portais
│   ├── desktop/                     # Configurações declarativas de interface do usuário (~/.config)
│   │   ├── niri/
│   │   │   └── config.kdl           # Configuração com atalhos 1:1 equivalentes em sintaxe KDL
│   │   └── umbriel/
│   │       ├── config.toml          # Configuração personalizada (atalhos, mouse, teclas Fn)
│   │       └── noctalia.toml        # Include opcional intencionalmente vazio para customizações locais
│   └── system/                      # Modelos declarativos do sistema operacional (/etc)
│       ├── greetd.toml.template     # Modelo de configuração do Greetd
│       ├── pam_greetd.template      # Modelo de autenticação PAM para o Greetd
│       └── pam_sddm.template        # Modelo de autenticação PAM para o SDDM
├── lib/
│   ├── ui.sh                        # Renderização ANSI: banner dinâmico (TARGET_FEDORA_VERSION), caixas temáticas e prompts validados (ui_ask_choice/ui_ask_yn)
│   ├── logger.sh                    # Registro em $XDG_STATE_HOME/fedora-multi-shell/install.log (fora de /tmp) e traps de erro
│   └── utils.sh                     # Validação de não-root, resolução segura via getent, install_packages_from_conf e cleanup do sudoers
└── modules/
    ├── 00_repos.sh                  # Repositórios (RPM Fusion, Brave, Flathub, COPRs condicionais, Terra e DankLinux)
    ├── 01_system_hardware.sh        # Firmware, microcódigo de CPU, PipeWire, som e energia (Tuned)
    ├── 02_gpu_drivers.sh            # Drivers Mesa abertos (via mesa.conf) ou NVIDIA com akmods
    ├── 03_desktop_apps.sh           # Camada de Usuário: Kitty, fontes, codecs, Brave Origin e Flatpaks
    ├── 04_display_stack.sh          # Camada de Display Manager: SDDM ou Greetd (Noctalia/DMS) e integração PAM Keyring
    ├── 05_compositor.sh             # Roteador de Compositor (Padrão Strategy)
    ├── 06_desktop_interface.sh      # Roteador de Interface Gráfica (Padrão Strategy)
    ├── 07_post_install.sh           # Autostart/config da interface, ABNT2, VM flags, ativação DM e validações
    ├── compositors/
    │   ├── niri.sh                  # Niri (--exclude=alacritty), remoção defensiva, xwayland-satellite e portais
    │   └── umbriel.sh               # Umbriel Nightly, xwayland-satellite e portais Umbriel/GTK
    └── interfaces/
        ├── inir.sh                  # Deno (sha256/arquitetura), clone e ./setup install -y sob o usuário real
        ├── noctalia.sh              # Pacote nativo 'noctalia' e 'noctalia-greeter' via DNF
        └── danklinux.sh             # Instalador oficial headless do DankMaterialShell (DMS)
```

---

## 🎯 Matriz de Combinações Suportadas

| Opção de Interface Gráfica  | Compositor Wayland | Características Principais                                                                                                                                                        |
| :-------------------------- | :----------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **iNiR Shell**              | **Niri** (Fixo)    | Estética moderna com cores dinâmicas Material You, widgets e rolagem horizontal de janelas contínua.                                                                              |
| **Noctalia Shell**          | **Niri**           | Shell nativa em C++/Qt com painel clássico/moderno sobre o motor de rolagem horizontal contínua do Niri.                                                                          |
| **Noctalia Shell**          | **Umbriel**        | Shell nativa em C++/Qt sobre Umbriel, compositor Wayland dinâmico com rolagem contínua de janelas (horizontal e vertical), além de múltiplos modos de janelas (Dwindle e Master). |
| **DankMaterialShell (DMS)** | **Niri** (Fixo)    | Ambiente DankLinux com painéis Material You, dms-greeter (Greetd), danksearch, dankcalendar e terminal Kitty fixado.                                                              |

---

## 🚀 Guia de Instalação Passo a Passo

### 1. Preparação da Mídia (Fedora Everything Netinstall)

1. Baixe a imagem ISO do **Fedora Everything** no site oficial do Fedora.
2. Na tela de **Seleção de Programas (Software Selection)** do instalador Anaconda:
   - Selecione **Minimal Install** (Instalação Mínima).
3. Crie o seu usuário comum e marque a opção para **torná-lo administrador**.

### 2. Executando o Instalador

Após reiniciar no console TTY com seu usuário comum:

```bash
# 1. Instale o git para clonar o repositório
sudo dnf install -y git

# 2. Clone o instalador
git clone https://github.com/danieldemoura/fedora-multishell.git
cd fedora-multishell

# 3. Dê permissão de execução
chmod -R +x install.sh modules/

# 4. Inicie o instalador como USUÁRIO COMUM (NÃO execute com sudo!)
./install.sh
```

---

## 📋 Interface CLI Padronizada (pt-BR)

O instalador conta com um menu interativo sem poluição visual:

- Prompts numéricos utilizam a sintaxe direta: `Escolha uma opção: ` (pressionar Enter assume `1`).
- Prompts booleanos adotam a convenção Unix de letra maiúscula para a opção padrão:
  - `Deseja instalar os drivers proprietários da NVIDIA? [s/N]: ` (Enter assume `N`).
  - `Deseja configurar o padrão Brasileiro ABNT2 (com tecla ç)? [S/n]: ` (Enter assume `S`).
  - `Deseja iniciar a instalação com estas definições? [S/n]: ` (Enter assume `S`).
  - `Deseja reiniciar o sistema agora? [S/n]: ` (Enter assume `S` e executa reinicialização imediata com `sudo reboot`).

---

## 🛡️ Tabela Formal de Decisões de Engenharia Defensiva

| Decisão Arquitetural / Defensiva                                             | Justificativa Técnica e Prevenção de Falhas                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| :--------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Autorização do Noctalia Greeter (`passwordless-sync`)**                    | O diretório `/var/lib/noctalia-greeter` com posse de `greetd:greetd` e a execução de `noctalia-greeter passwordless-sync enable` autorizam formalmente via Polkit a sincronização bidirecional do papel de parede e temas do desktop com a tela de login sem exigir senha administrativa.                                                                                                                                                                                                                                             |
| **Desativação preventiva de GDM / LightDM / Greetd**                         | Evita conflitos de display manager caso o script seja reexecutado ou utilizado sobre Fedora Workstation/Spins que contenham outros gerenciadores pré-instalados. Previne dois daemons disputando o mesmo dispositivo DRM/KMS.                                                                                                                                                                                                                                                                                                         |
| **Execução de `sudo -v` antecipado em `interfaces/inir.sh`**                     | Em etapas anteriores demoradas (como o download de aplicativos e codecs no Módulo 03), o timestamp padrão do `sudo` pode expirar. Atualizar o timestamp explicitamente antes de acionar `./setup install -y` impede que o instalador do iNiR trave esperando senha de administrador em background.                                                                                                                                                                                                                                    |
| **Isolamento e verificação SHA-256 do download do Deno na Home (`${REAL_HOME}`)**  | Em sistemas Fedora modernos, `/tmp` é montado como `tmpfs` em memória RAM. Em máquinas virtuais com 2GB-4GB de memória, arquivos temporários podem esgotar inodes/espaço (`curl: (23) Failure writing output to destination`). Utilizar a Home garante armazenamento persistente em disco. Além disso, a arquitetura do binário é detectada por `uname -m` e o pacote é confrontado com o checksum SHA-256 oficial da release antes de ser instalado em `/usr/local/bin`.                                                                                          |
| **Distinção entre layout ABNT2 e idioma nativo das interfaces**              | A injeção de `layout "br"` no bloco `xkb` do Niri ou no `[input.keyboard]` do Umbriel mapeia unicamente a tabela de scancodes físicos (tecla `Ç`, acentos `~` e `^`), desacoplada do idioma da interface gráfica que permanece em inglês nativo.                                                                                                                                                                                                                                                                                      |
| **Instalação antecipada de aplicativos no Módulo 03**                        | Instalar Kitty, fontes Google Noto e codecs antes da configuração do compositor e da shell garante que todas as dependências visuais e ferramentas de terminal já estejam no disco antes de a interface gráfica ser compilada, configurada ou validada.                                                                                                                                                                                                                                                                               |
| **Templates Declarativos vs `/usr/share/doc`**                               | A adoção de templates próprios na pasta do instalador elimina a dependência de arquivos de exemplo do sistema operacional (que sofrem com caminhos versionados no Fedora e causavam o erro de atalhos vazios `not bound`), garantindo que tanto o Niri quanto o Umbriel iniciem com mapeamento completo de atalhos, mouse e teclas Fn.                                                                                                                                                                                                |
| **Injeção Dinâmica de Variáveis de VM vs Templates Limpos**                  | Os arquivos em `config/desktop/` são mantidos intencionalmente limpos e otimizados para Máquinas Físicas (Bare Metal). A injeção das variáveis de ambiente (`LIBGL_ALWAYS_SOFTWARE=1`, `WLR_NO_HARDWARE_CURSORS=1` e `hardware_cursor = false`) ocorre em tempo de execução via `07_post_install.sh` somente se `IS_VM=true`, protegida por guarda de idempotência (`grep -qF`). Isso previne que computadores reais com GPU dedicada tenham sua aceleração desativada, ao mesmo tempo em que blinda máquinas virtuais contra telas pretas e fechamentos inesperados (_crashes_) do QtQuick. |
| **Isolamento de Templates por Shell**                                        | A cópia dos templates do Umbriel e Niri ocorre estritamente quando `SELECTED_SHELL="noctalia"`, preservando a autonomia e configuração gerada pelo instalador nativo do iNiR quando este for o escolhido.                                                                                                                                                                                                                                                                                                                             |
| **Autostart e VM Flags do iNiR no Niri**                                     | O instalador nativo do iNiR copia seus arquivos para `~/.config/quickshell/inir`, mas não adiciona a chamada de inicialização nem as variáveis de renderização de VM no Niri. Embora os templates específicos do Noctalia não sejam aplicados ao iNiR, o Módulo 07 injeta explicitamente o `spawn-at-startup "inir" "run"`, o layout ABNT2 e o bloco `environment` de software rendering para VM no `config.kdl`, prevenindo a falha de tela cinza vazia após o login no SDDM.                                                        |
| **Exclusão e Remoção Defensiva do Alacritty (`compositors/niri.sh`)**        | O pacote upstream do Niri pode trazer o Alacritty como dependência recomendada ou fraca. A flag `--exclude=alacritty` aliada à remoção defensiva subsequente garante que apenas o Kitty permaneça como emulador de terminal oficial do sistema, sem quebrar as outras dependências normais e fracas do Niri.                                                                                                                                                                                                                          |
| **Autorização Administrativa Temporária no Sudoers (validada via `visudo`)**                        | A criação do drop-in `/etc/sudoers.d/99-fedora-installer-temp` com `trap` de autodestruição (`EXIT HUP INT TERM`) elimina o timeout de credenciais do sudo (5 minutos) durante etapas demoradas não-interativas. O fluxo é endurecido: a regra é montada em `mktemp`, **validada com `sudo visudo -cf`** antes de tocar `/etc/sudoers`, instalada com `install -m 0440` e precedida da remoção de drop-in órfão de execuções anteriormente interrompidas, sem deixar resquícios NOPASSWD.                                                                                           |

---

## ⌨️ Atalhos de Teclado Nativos e Controle

### Niri

> Atalhos extraídos diretamente de `config/desktop/niri/config.kdl` (`Mod` = <kbd>Super</kbd>).

| Atalho                                                                        | Ação                                                          |
| :---------------------------------------------------------------------------- | :------------------------------------------------------------ |
| <kbd>Super</kbd> + <kbd>Return</kbd>                                          | Abre o Terminal GPU (`kitty`)                                 |
| <kbd>Super</kbd> + <kbd>Space</kbd>                                           | Abre o lançador de aplicativos (launcher do Noctalia)         |
| <kbd>Super</kbd> + <kbd>Q</kbd>                                               | Fecha a janela em foco                                        |
| <kbd>Super</kbd> + <kbd>H</kbd> ou <kbd>←</kbd>                               | Foca a coluna anterior (rolagem horizontal)                   |
| <kbd>Super</kbd> + <kbd>→</kbd>                                               | Foca a coluna próxima                                         |
| <kbd>Super</kbd> + <kbd>J</kbd> / <kbd>K</kbd> ou <kbd>↓</kbd> / <kbd>↑</kbd> | Foca a janela inferior / superior dentro da coluna            |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>←</kbd> / <kbd>→</kbd>             | Move a coluna atual para a esquerda / direita                 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>↑</kbd> / <kbd>↓</kbd>             | Move a janela dentro da coluna                                |
| <kbd>Super</kbd> + <kbd>L</kbd>                                               | Bloqueia a sessão (`noctalia msg session lock`)               |
| <kbd>Super</kbd> + <kbd>Esc</kbd>                                             | Encerra a sessão (logout)                                     |

### Umbriel

| Atalho                                  | Ação                                                                    |
| :-------------------------------------- | :---------------------------------------------------------------------- |
| <kbd>Super</kbd> + <kbd>Return</kbd>    | Abre o Terminal GPU (`kitty`)                                           |
| <kbd>Super</kbd> + <kbd>Q</kbd>         | Fecha a janela em foco                                                  |
| <kbd>Super</kbd> + Navegação de Janelas | Rolagem contínua bidirecional e comutação de layouts (Dwindle e Master) |

### DankLinux (DankMaterialShell / DMS)

> ⚠️ Os atalhos do DMS são definidos pelos **padrões upstream** do DankMaterialShell e do Niri (instalados pelo `dankinstall`), não por templates deste instalador. A tabela abaixo é ilustrativa — confira o painel/atalhos oficiais do DMS após a instalação.

| Atalho                                                                        | Ação                                                                      |
| :---------------------------------------------------------------------------- | :------------------------------------------------------------------------ |
| <kbd>Super</kbd> + <kbd>T</kbd>                                               | Abre o Terminal GPU (`kitty`)                                             |
| <kbd>Super</kbd> + <kbd>Q</kbd>                                               | Fecha a janela em foco                                                    |
| <kbd>Super</kbd> + <kbd>Space</kbd> / <kbd>D</kbd>                            | Lança o menu de aplicativos / busca (`danksearch`)                        |
| <kbd>Super</kbd> + <kbd>H</kbd> / <kbd>L</kbd> ou <kbd>←</kbd> / <kbd>→</kbd> | Foca a coluna anterior / próxima no compositor Niri                       |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> / <kbd>L</kbd>             | Move a coluna atual para a esquerda / direita                             |
| Controles DMS / Niri                                                          | Gestão de painéis, notificações e widgets integrados do DankMaterialShell |
