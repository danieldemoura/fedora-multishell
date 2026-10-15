# 🌌 Fedora Wayland Workstation: iNiR & Noctalia Installer

Instalador modular, em camadas e automatizado para transformar uma instalação mínima do **Fedora (Netinstall / Everything)** em uma workstation gráfica moderna com suporte à seleção exclusiva de **Desktop Shell** e **Compositor Wayland**:

* **Interfaces Gráficas (Desktop Shells):**
  * **iNiR Shell:** Interface moderna baseada em Quickshell, C++/Qt e theming dinâmico Material You via COPR `errornointernet/quickshell` (utiliza exclusivamente o compositor Niri).
  * **Noctalia Shell:** Interface gráfica desktop nativa em C++/Qt via pacote nativo Fedora (permite escolher entre o compositor Niri ou Umbriel).
* **Compositores Wayland de Alta Performance:**
  * **Niri:** Scrollable tiling Wayland compositor com rolagem horizontal contínua de colunas via COPR `yalter/niri`.
  * **Umbriel:** Compositor Wayland dinâmico via Repositório Terra do Fyra Labs, com suporte à rolagem contínua de janelas (horizontal e vertical), além de múltiplos modos de exibição dinâmicos (Dwindle e Master).
* **Display Manager / Gerenciador de Login:** [SDDM](https://github.com/sddm/sddm) nativo com integração e desbloqueio silencioso do PAM GNOME Keyring.
* **Emulador de Terminal & CLI:** [Kitty](https://sw.kovidgoyal.net/kitty/) (acelerado por GPU) + `fastfetch` (resumo de hardware).
* **Compatibilidade X11:** `xwayland-satellite` (rootless isolado).
* **Navegador Web:** Brave Origin (sem telemetria, IA ou criptomoedas).
* **Loja de Apps:** GNOME Software (Loja gráfica nativa com integração ao Flathub e atualizações de sistema).
* **Reprodutor de Vídeo:** Cine (`io.github.diegopvlk.Cine` via Flatpak).

---

## 🏗️ Arquitetura em Camadas (Layered Architecture)

O projeto adota os princípios de **Separação de Preocupações (SoC)**, **Idempotência** e **Padrão Strategy** para despachar submódulos de compositores e shells. Os pacotes de usuário (fontes, terminal Kitty e codecs) são instalados no Módulo 03, garantindo ambiente pronto antes de subir a stack visual:

```text
fedora-inir/
├── setup.sh                         # Ponto de entrada: checagens, menu interativo pt-BR e orquestrador
├── config/
│   ├── packages-base.conf           # Infraestrutura do sistema (Firmware, SDDM, Áudio, Portais)
│   ├── packages-apps.conf           # Aplicações de usuário, fontes Noto, terminal Kitty e codecs
│   ├── packages-flatpak.conf        # Lista declarativa de aplicativos Flatpak do Flathub
│   ├── packages-nvidia.conf         # Pilha proprietária de drivers e módulos NVIDIA (akmods)
│   └── settings.conf                # Variáveis globais, repositórios e flags padrão
├── lib/
│   ├── ui.sh                        # Renderização ANSI: banner sem subtítulo fixo, caixas temáticas e prompts limpos
│   ├── logger.sh                    # Registro em /tmp/fedora-inir-installer.log e traps de erro
│   └── utils.sh                     # Sudo keepalive, validação de não-root e permissões
├── modules/
│   ├── 00_repos.sh                  # Repositórios (RPM Fusion, Brave, Flathub, COPRs condicionais e Terra)
│   ├── 01_system_hardware.sh        # Firmware, microcódigo de CPU, PipeWire, som e energia (Tuned)
│   ├── 02_gpu_drivers.sh            # Drivers Mesa abertos ou NVIDIA com akmods
│   ├── 03_desktop_apps.sh           # Camada de Usuário: Kitty, fontes, codecs, Brave Origin e Flatpaks
│   ├── 04_display_stack.sh          # Camada de Display Manager: SDDM ou Greetd/Noctalia Greeter e integração PAM Keyring
│   ├── 05_compositor.sh             # Roteador de Compositor (Padrão Strategy)
│   │   └── compositors/
│   │       ├── niri.sh              # Niri, xwayland-satellite e portais GNOME/GTK
│   │       └── umbriel.sh           # Umbriel Nightly, xwayland-satellite e portais Umbriel/GTK
│   ├── 06_desktop_shell.sh          # Roteador de Shell (Padrão Strategy)
│   │   └── shells/
│   │       ├── inir.sh              # Deno (/usr/local/bin), sudo -v antecipado, clone, ./setup install -y
│   │       └── noctalia.sh          # Pacote nativo 'noctalia' via DNF
│   └── 07_post_install.sh           # Autostart da shell, ABNT2, VM flags, ativação SDDM e validações
└── templates/
    └── pam_sddm.template            # Configuração do Gnome Keyring no PAM para o SDDM
```

---

## 🎯 Matriz de Combinações Suportadas

| Opção de Shell | Compositor Wayland | Características Principais |
| :--- | :--- | :--- |
| **iNiR Shell** | **Niri** (Fixo) | Estética moderna com cores dinâmicas Material You, widgets e rolagem horizontal de janelas contínua. |
| **Noctalia Shell** | **Niri** | Shell nativa em C++/Qt com painel clássico/moderno sobre o motor de rolagem horizontal contínua do Niri. |
| **Noctalia Shell** | **Umbriel** | Shell nativa em C++/Qt sobre Umbriel, compositor Wayland dinâmico com rolagem contínua de janelas (horizontal e vertical), além de múltiplos modos de janelas (Dwindle e Master). |

---

## 🚀 Guia de Instalação Passo a Passo

### 1. Preparação da Mídia (Fedora Netinstall)
1. Baixe a imagem ISO do **Fedora Everything (Netinstall)** no site oficial.
2. Na tela de **Seleção de Programas (Software Selection)** do instalador Anaconda:
   - Selecione **Minimal Install** (Instalação Mínima).
3. Crie o seu usuário comum e marque a opção para **torná-lo administrador (`wheel`)**.

### 2. Executando o Instalador

Após reiniciar no console tty com seu usuário comum:

```bash
# 1. Instale o git para clonar o repositório
sudo dnf install -y git

# 2. Clone o instalador
git clone https://github.com/seu-usuario/fedora-inir.git
cd fedora-inir

# 3. Dê permissão de execução
chmod +x setup.sh modules/*.sh modules/compositors/*.sh modules/shells/*.sh

# 4. Inicie o instalador como USUÁRIO COMUM (NÃO execute com sudo!)
./setup.sh
```

---

## 📋 Interface CLI Padronizada (pt-BR)

O instalador conta com um menu interativo sem poluição visual:
* Prompts numéricos utilizam a sintaxe direta: `Escolha uma opção: ` (pressionar Enter assume `1`).
* Prompts booleanos adotam a convenção Unix de letra maiúscula para a opção padrão:
  * `Deseja instalar os drivers proprietários da NVIDIA? [s/N]: ` (Enter assume `N`).
  * `Deseja configurar o padrão Brasileiro ABNT2 (com tecla ç)? [S/n]: ` (Enter assume `S`).
  * `Deseja iniciar a instalação com estas definições? [S/n]: ` (Enter assume `S`).
  * `Deseja reiniciar o sistema agora? [S/n]: ` (Enter assume `S` e executa reinicialização imediata com `sudo reboot`).

---

## 🛡️ Tabela Formal de Decisões de Engenharia Defensiva

| Decisão Arquitetural / Defensiva | Justificativa Técnica e Prevenção de Falhas |
| :--- | :--- |
| **Autorização do Noctalia Greeter (`passwordless-sync`)** | O diretório `/var/lib/noctalia-greeter` com posse de `greetd:greetd` e a execução de `noctalia-greeter passwordless-sync enable` autorizam formalmente via Polkit a sincronização bidirecional do papel de parede e temas do desktop com a tela de login sem exigir senha administrativa. |
| **Desativação preventiva de GDM / LightDM / Greetd** | Evita conflitos de display manager caso o script seja reexecutado ou utilizado sobre Fedora Workstation/Spins que contenham outros gerenciadores pré-instalados. Previne dois daemons disputando o mesmo dispositivo DRM/KMS. |
| **Execução de `sudo -v` antecipado em `shells/inir.sh`** | Em etapas anteriores demoradas (como o download de aplicativos e codecs no Módulo 03), o timestamp padrão do `sudo` pode expirar. Atualizar o timestamp explicitamente antes de acionar `./setup install -y` impede que o instalador do iNiR trave esperando senha de administrador em background. |
| **Isolamento do download do Deno na Home (`${REAL_HOME}`) em vez do `/tmp`** | Em sistemas Fedora modernos, `/tmp` é montado como `tmpfs` em memória RAM. Em máquinas virtuais com 2GB-4GB de memória, arquivos temporários podem esgotar inodes/espaço (`curl: (23) Failure writing output to destination`). Utilizar a Home garante armazenamento persistente em disco. |
| **Distinção entre layout ABNT2 e idioma nativo das interfaces** | A injeção de `layout "br"` no bloco `xkb` do Niri ou no `[input.keyboard]` do Umbriel mapeia unicamente a tabela de scancodes físicos (tecla `Ç`, acentos `~` e `^`), desacoplada do idioma da interface gráfica que permanece em inglês nativo. |
| **Instalação antecipada de aplicativos no Módulo 03** | Instalar Kitty, fontes Google Noto e codecs antes da configuração do compositor e da shell garante que todas as dependências visuais e ferramentas de terminal já estejam no disco antes de a interface gráfica ser compilada, configurada ou validada. |

---

## ⌨️ Atalhos de Teclado Nativos e Controle

### Niri
| Atalho | Ação |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Abre o Terminal GPU (`kitty`) |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Fecha a janela em foco |
| <kbd>Super</kbd> + <kbd>H</kbd> / <kbd>L</kbd> ou <kbd>←</kbd> / <kbd>→</kbd> | Foca a coluna anterior / próxima (rolagem horizontal) |
| <kbd>Super</kbd> + <kbd>J</kbd> / <kbd>K</kbd> ou <kbd>↓</kbd> / <kbd>↑</kbd> | Foca a janela inferior / superior dentro da coluna |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> / <kbd>L</kbd> | Move a coluna atual para a esquerda / direita |

### Umbriel
| Atalho | Ação |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Abre o Terminal GPU (`kitty`) |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Fecha a janela em foco |
| <kbd>Super</kbd> + Navegação de Janelas | Rolagem contínua bidirecional e comutação de layouts (Dwindle e Master) |
