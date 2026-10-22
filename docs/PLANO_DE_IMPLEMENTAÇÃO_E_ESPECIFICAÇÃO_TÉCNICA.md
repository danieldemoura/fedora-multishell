# PLANO DE IMPLEMENTAÇÃO E ESPECIFICAÇÃO TÉCNICA

## Projeto: Fedora Minimal (Netinstall) → Pure Wayland Workstation

**Stack Gráfica Modular:**

- **Compositores Suportados:**
  - **Niri** (`yalter/niri` via COPR): Scrollable-tiling Wayland compositor com rolagem horizontal contínua de colunas e janelas.
  - **Umbriel** (`umbriel-nightly` via Repositório Terra do Fyra Labs): Compositor Wayland com rolagem contínua de janelas (horizontal e vertical), além de múltiplos modos de exibição dinâmicos (Dwindle e Master).
- **Desktop Shells / Interfaces Suportadas:**
  - **iNiR Shell** (`snowarch/inir` via `quickshell`): Shell moderna baseada em Quickshell, C++/Qt e theming dinâmico Material You. Utiliza exclusivamente o compositor Niri.
  - **Noctalia Shell** (`noctalia` via pacote nativo Fedora): Interface gráfica desktop nativa em C++/Qt. Permite utilizar tanto o compositor Niri quanto o compositor Umbriel.
  - **Dux Shell / DMS** (instalador oficial `install.duxlabs.dev` via COPR `avengemedia/danklinux`): Ambiente completo da Dux Labs (ex-DankLinux/DankMaterialShell, renomeado no release 2.0) sobre Niri com terminal Kitty, dms-greeter, danksearch e dankcalendar.
- **Display Manager:** **SDDM** (`sddm` nativo com integração e desbloqueio do PAM GNOME Keyring) ou **Greetd** (`noctalia-greeter` / `dms-greeter`).

**Público-Alvo:** Desenvolvedor / Modelo de IA Gerador de Código  
**Versão Base Alvo:** Fedora 44 (x86_64)

---

## 1. DIRETRIZES DE ENGENHARIA E ARQUITETURA MODULAR

O script de instalação é estruturado estritamente sob os padrões de **Arquitetura em Camadas (Layered Architecture)**, **Separação de Preocupações (SoC)** e **Idempotência**.

A nova orquestração em camadas garante que toda a base do sistema e as ferramentas de usuário (incluindo emulador de terminal Kitty, fontes tipográficas, visualizadores e codecs) sejam provisionadas no disco antes da camada de interface gráfica e compositores ser configurada.

### 1.1 Árvore Estrutural do Projeto

```text
fedora-multishell/
├── install.sh                       # Ponto de entrada: validações, menu interativo pt-BR e orquestração
├── docs/
│   ├── PLANO_DE_IMPLEMENTAÇÃO_E_ESPECIFICAÇÃO_TÉCNICA.md # Especificação técnica completa
│   ├── CATALOGO_DE_PACOTES.md       # Catálogo detalhado e mapeamento de dependências
│   └── DIRETRIZES_DE_ARQUITETURA_E_BOAS_PRATICAS.md # Regras de engenharia e boas práticas
├── config/
│   ├── settings.conf                # Variáveis globais (repositórios, versões, flags de ambiente)
│   ├── packages/                    # Manifestos declarativos de pacotes (DNF / Flatpak)
│   │   ├── apps.conf                # Aplicações universais de usuário (Kitty, Nautilus, Codecs)
│   │   ├── base.conf                # Infraestrutura base do sistema (Hardware, Som, Rede, VM)
│   │   ├── brave.conf               # Manifesto de instalação do navegador Brave Browser
│   │   ├── flatpak.conf             # Lista declarativa de aplicativos Flatpak do Flathub
│   │   ├── greetd.conf              # Daemons base do Display Manager Greetd
│   │   ├── inir.conf                # Dependências, runtimes e shaders do iNiR / Iris / Quickshell
│   │   ├── mesa.conf                # Pilha aberta de aceleração gráfica Mesa (DRI/Vulkan/VA-API/switcheroo)
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
│   ├── ui.sh                        # Renderização visual ANSI (banners limpos, caixas temáticas, prompts validados pt-BR)
│   ├── logger.sh                    # Registro centralizado (`$XDG_STATE_HOME/fedora-multi-shell/install.log`) e tratamento de erros
│   └── utils.sh                     # Utilitários (checagem de não-root, permissões seguras, install_packages_from_conf, cleanup do sudoers)
└── modules/
    ├── 00_repos.sh                  # Repositórios universais (RPM Fusion, Brave, Flathub) e condicionais (COPRs, Terra, Dux Labs)
    ├── 01_system_hardware.sh        # Firmware, microcódigo de CPU, PipeWire, rede e energia (Tuned)
    ├── 02_gpu_drivers.sh            # Drivers gráficos (Mesa aberto via mesa.conf ou NVIDIA com akmods e RTD3)
    ├── 03_desktop_apps.sh           # Camada de Usuário: Kitty, fontes, codecs, Brave Origin, Flatpaks e Loja GNOME
    ├── 04_display_stack.sh          # Camada de Display Manager: SDDM ou Greetd (Noctalia/DMS), hardware e PAM Keyring
    ├── 05_compositor.sh             # Roteador/Dispatcher de Compositor Wayland (Padrão Strategy)
    ├── 06_desktop_interface.sh      # Roteador/Dispatcher de Interface Gráfica (Padrão Strategy)
    ├── 07_post_install.sh           # Autostart/config da interface, VM flags, validação de configs e ativação do DM
    ├── compositors/
    │   ├── niri.sh                  # Submódulo: Niri, xwayland-satellite, portais GNOME/GTK e niri-portals.conf
    │   └── umbriel.sh               # Submódulo: Umbriel Nightly, xwayland-satellite e portais Umbriel/GTK
    └── interfaces/
        ├── inir.sh                  # Submódulo: Deno (/usr/local/bin, sha256), clone, ./setup install -y
        ├── noctalia.sh              # Submódulo: Instalação declarativa de 'noctalia' e 'noctalia-greeter'
        └── duxshell.sh              # Submódulo: Instalador oficial headless do Dux Shell (DMS)
```

### 1.2 Regras Estritas de Programação Shell

1. **Defensividade:** Todos os scripts rodam com `set -euo pipefail`.
2. **Execução sem Root Direto:** O script deve recusar ser executado diretamente com `sudo ./install.sh`. Ele é iniciado pelo usuário comum (`./install.sh`) e invoca `sudo` apenas onde necessário.
3. **Idempotência:** A reexecução do script (ou de módulos individuais) não deve duplicar linhas em arquivos de configuração (`grep -qF` antes de inserir).
4. **Isolamento Declarativo e IaC:** Listas em `config/` contêm um pacote ou identificador por linha, ignorando comentários e linhas em branco. Scripts procedurais não contêm comandos `dnf install` com pacotes fixos; todas as instalações são processadas via `install_packages_from_conf`. **Exceções justificadas e únicas:** bootstrap de repositórios (RPMs de release do RPM Fusion, `dnf-plugins-core`, `flatpak`, COPRs) e microcódigo de CPU (escolhido condicionalmente pela arquitetura detectada), pois antecedem ou escapam ao modelo de manifesto estático.
5. **Validação de Entrada Interativa:** Todo prompt do menu rejeita e repergunta entradas fora do conjunto de opções documentado (nunca cai silenciosamente em um padrão).

---

## 2. MATRIZ DE OPÇÕES SUPORTADAS E COMPOSITORES

O instalador suporta as seguintes combinações completas de ambiente gráfico:

| Desktop Shell       | Compositor Wayland | Repositórios Necessários                                | Descrição e Paradigma de Janelas                                                                                                                                          |
| :------------------ | :----------------- | :------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **iNiR Shell**      | **Niri** (Fixo)    | COPR `yalter/niri`<br>COPR `errornointernet/quickshell` | Shell moderna inspirada em Material You rodando sobre Niri com rolagem horizontal infinita de colunas e janelas.                                                          |
| **Noctalia Shell**  | **Niri**           | COPR `yalter/niri`<br>Repositório Terra (Fyra Labs)     | Shell nativa em C++/Qt sobre Niri, aliando a estética de desktop tradicional/moderna à rolagem horizontal contínua de janelas e tela de login com Noctalia Greeter.       |
| **Noctalia Shell**  | **Umbriel**        | Repositório Terra (Fyra Labs)                           | Shell nativa em C++/Qt sobre Umbriel, compositor Wayland dinâmico com suporte a rolagem contínua (horizontal e vertical) e múltiplos modos de janelas (Dwindle e Master). |
| **Dux Shell (DMS)** | **Niri** (Fixo)    | COPR `yalter/niri`<br>COPR `avengemedia/danklinux`      | Ambiente completo Dux Labs sobre Niri com terminal Kitty acelerado por GPU, dms-greeter (Greetd), danksearch e dankcalendar.                                              |

---

## 3. DESIGN E FLUXO DA INTERFACE CLI (PT-BR)

O menu interativo CLI segue um design visual enxuto, sem poluição de mensagens do tipo `(Padrão: ...)` e adotando rigorosamente a convenção Unix de maiúsculas para opções padrão.

### 3.1 Banner ASCII e Rodapé

```text
  ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗
  ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗
  █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║
  ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║
  ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║
  ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝

  Fedora 44 Minimal | Pure Wayland | Out-of-the-box
```

### 3.2 Fluxo de Interação

Todos os prompts são processados pelos helpers validados `ui_ask_choice` / `ui_ask_yn` (`lib/ui.sh`): entradas fora do conjunto de opções são rejeitadas com aviso e reperguntadas em loop (nunca há queda silenciosa para um padrão). Pressionar Enter assume a opção padrão documentada.

1. **SELEÇÃO DO AMBIENTE DE INSTALAÇÃO:** `[1] Máquina Física` ou `[2] Máquina Virtual`. Prompt: `Escolha uma opção: ` (Enter assume `1`).
2. **SELEÇÃO DA INTERFACE GRÁFICA (DESKTOP SHELL):** `[1] iNiR Shell`, `[2] Noctalia Shell` ou `[3] Dux Shell (DMS)`. Prompt: `Escolha uma opção: ` (Enter assume `1`).
   - Se `Noctalia Shell`: exibe sub-pergunta de compositor `[1] Niri` ou `[2] Umbriel`. Prompt: `Escolha uma opção: ` (Enter assume `1`).
   - Se `iNiR Shell` ou `Dux Shell`: fixa automaticamente o compositor como `niri`.
3. **DRIVER DE VÍDEO DEDICADO (NVIDIA):** Apenas se Máquina Física. Prompt: `Deseja instalar os drivers proprietários da NVIDIA? [s/N]: ` (Enter assume `N`).
4. **RESUMO DAS DEFINIÇÕES DA SESSÃO:** Exibe Ambiente, Interface Gráfica, Compositor e GPU. Prompt: `Deseja iniciar a instalação com estas definições? [S/n]: ` (Enter assume `S`).
5. **PROMPT DE CONCLUSÃO:** `Deseja reiniciar o sistema agora? [S/n]: ` (Enter assume `S` e dispara `sudo reboot`).

Antes do menu, o `install.sh` valida pré-requisitos: recusa execução direta como root, garante usuário real não vazio (`getent`) e compara a release detectada (`rpm -E %fedora`) com `TARGET_FEDORA_VERSION` do `config/settings.conf` — divergência gera aviso interativo com opt-in explícito para continuar, não bloqueio cego.

---

## 4. ORQUESTRAÇÃO EM CAMADAS E DETALHAMENTO DOS MÓDULOS

A execução sequencial segue estritamente a ordem:

```bash
modules=(
    "00_repos.sh"
    "01_system_hardware.sh"
    "02_gpu_drivers.sh"
    "03_desktop_apps.sh"
    "04_display_stack.sh"
    "05_compositor.sh"
    "06_desktop_interface.sh"
    "07_post_install.sh"
)
```

Nenhum módulo executa comandos `dnf install` com listas de pacotes fixos (hardcoded). Todos utilizam a função central `install_packages_from_conf` apontando para seus respectivos manifestos `.conf`.

### Módulo 00: Repositórios e Fontes Condicionais (`00_repos.sh`)

- Otimização de mirrors: habilita `fastestmirror=True` no `/etc/dnf/dnf.conf` (idempotente, inserido sob `[main]`), fazendo repositórios metalink (Fedora, RPM Fusion, COPRs) priorizarem o mirror de menor latência medida.
- Repositórios universais: RPM Fusion Free e Nonfree (bootstrap com download local do RPM de release: tentativa 1 no servidor-mestre direto `download1.rpmfusion.org`; retentativas na roleta `mirrors.rpmfusion.org` com alternância IPv4 — instalado a partir do arquivo local), Brave Browser e Flathub.
- Repositórios condicionais:
  - Se `SELECTED_COMPOSITOR == "niri"`: ativa COPR `yalter/niri`.
  - Se `SELECTED_SHELL == "inir"`: ativa COPR `errornointernet/quickshell`.
  - Se `SELECTED_SHELL == "noctalia"`: ativa o repositório Terra do Fyra Labs (`terra-release` e `terra-gpg-keys`, necessário para `noctalia-greeter` e `umbriel-nightly`).
  - Se `SELECTED_INTERFACE == "duxshell"`: ativa o repositório COPR `avengemedia/danklinux` (repos oficiais da Dux Labs; os COPRs `duxlabs/*` ainda não estão prontos para produção).
- Atualização e sincronização via `dnf upgrade --refresh -y`.

### Módulo 01: Infraestrutura de Hardware e Áudio (`01_system_hardware.sh`)

- Microcódigo de processadores (Intel/AMD).
- Instalação declarativa dos pacotes de infraestrutura (`config/packages/base.conf`), serviços de som (PipeWire/WirePlumber), perfis de energia (`tuned`), Bluetooth, UDisks e impressão via `install_packages_from_conf`.

### Módulo 02: Drivers Gráficos e GPU (`02_gpu_drivers.sh`)

- Em VM: instalação apenas da base Mesa (DRI/Vulkan) via `install_packages_from_conf "${PACKAGES_DIR}/mesa.conf" "" "switcheroo-control,mesa-va-drivers-freeworld"` — os nomes são filtrados localmente antes de chamar o dnf (o dnf5 rejeita argumentos que "correspondem apenas a pacotes excluídos"); virtio-GPU não se beneficia de GPU híbrida nem de decodificação VA-API por hardware (o driver freeworld de VA-API continua sendo provido como codec na camada de aplicativos do Módulo 03 via `apps.conf`).
- Em Bare Metal: instalação declarativa da aceleração aberta Mesa DRI/Vulkan/VA-API e switcheroo-control via `install_packages_from_conf "${PACKAGES_DIR}/mesa.conf"`. Se NVIDIA for selecionado, instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/nvidia.conf"` e ativação dos serviços RTD3.

### Módulo 03: Camada de Aplicativos do Usuário (`03_desktop_apps.sh`)

- Sincronização RPM Fusion (`ffmpeg-free` -> `ffmpeg`).
- Instalação declarativa de ferramentas do usuário (`kitty`, `fastfetch`, `nautilus`, visualizadores GTK4, utilitários multimídia, fontes `google-noto-*`) via `install_packages_from_conf "${PACKAGES_DIR}/apps.conf"`.
- Instalação declarativa do Brave Origin via `install_packages_from_conf "${PACKAGES_DIR}/brave.conf"`, com contingência via script oficial upstream executado com privilégios administrativos (o instalador Brave escreve em `/etc/yum.repos.d`) ou pacote alternativo.
- Loja Nativa GNOME Software com integração Flathub e Flatpaks declarativos (`config/packages/flatpak.conf`, cuja sintaxe permite declarar overrides de permissão como tokens adicionais após o ID do app).
- Garante que a tipografia e o Kitty já existam no disco antes de a interface gráfica ser configurada.

### Módulo 04: Camada de Display Manager (`04_display_stack.sh`)

- **Se `SELECTED_INTERFACE == "duxshell"` (Greetd + DMS Greeter):**
  - Instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/greetd.conf"`.
  - Atribuição dos grupos de hardware `video,render,input` ao usuário `greetd`.
  - Aplicação do template de PAM `config/system/pam_greetd.template` em `/etc/pam.d/greetd` para desbloqueio do keyring.
- **Se `SELECTED_INTERFACE == "noctalia"` (Greetd + Noctalia Greeter):**
  - Instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/greetd.conf"`.
  - **Sequenciamento Antecipado do Noctalia Greeter:** Executa `install_packages_from_conf "${PACKAGES_DIR}/noctalia.conf"` previamente no Módulo 04 para disponibilizar os binários de `noctalia` e `noctalia-greeter`.
  - Configuração do diretório de estado `/var/lib/noctalia-greeter` (posse `greetd:greetd`).
  - Execução de `noctalia-greeter passwordless-sync enable "${REAL_USER}"` para autorização nativa Polkit da sincronização de aparência sem senha.
  - Atribuição dos grupos de hardware `video,render,input` ao usuário `greetd`.
  - Configuração do `/etc/greetd/config.toml` (com flags defensivas de software rendering para VM se aplicável).
  - Configuração de integração PAM em `/etc/pam.d/greetd` com `pam_gnome_keyring.so` para desbloqueio silencioso do cofre de senhas no login.
- **Se padrão (`sddm` / `inir`):**
  - Instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/sddm.conf"`.
  - Atribuição dos grupos de hardware `video,render,input` ao usuário `sddm`.
  - Configuração de integração PAM em `/etc/pam.d/sddm` com `pam_gnome_keyring.so` para desbloqueio silencioso do cofre de senhas no login (injeção via `awk` lida o arquivo vivo — não o `.bak` — e escrita atômica por arquivo temporário + `mv`).

### Módulo 05: Roteador de Compositor Wayland (`05_compositor.sh`)

- Despacha a execução para o submódulo correspondente (Padrão Strategy):
  - **`compositors/niri.sh`**: Instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/niri.conf" "" "alacritty"` (niri, xwayland-satellite, portais GNOME/GTK; alacritty filtrado localmente antes do dnf), remoção defensiva de resquícios do Alacritty e configuração de prioridade em `/etc/xdg/xdg-desktop-portal/niri-portals.conf`.
  - **`compositors/umbriel.sh`**: Instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/umbriel.conf"` (umbriel-nightly, xwayland-satellite, portais Umbriel e GTK).

### Módulo 06: Roteador de Interface Gráfica (`06_desktop_interface.sh`)

- Despacha a execução para o submódulo correspondente:
  - **`interfaces/inir.sh`**:
    - Instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/inir.conf"` (Quickshell, Qt6 Declarative, Qt5Compat e Qt SVG/Wayland).
    - Provisiona defensivamente o binário oficial do Deno em `/usr/local/bin/deno`: a arquitetura do alvo é detectada via `uname -m` (x86_64/aarch64; demais arquiteturas abortam com erro explícito), o download ocorre em `${REAL_HOME}` e o pacote é verificado contra o checksum SHA-256 publicado na release oficial antes de qualquer instalação.
    - Executa `sudo -v` imediatamente antes do instalador para renovar o timestamp administrativo.
    - Clona `https://github.com/snowarch/inir.git` para `${REAL_HOME}/.config/inir`.
    - Executa de forma não-interativa sob o usuário real: `sudo -u "${REAL_USER}" bash -c "cd '${REAL_HOME}/.config/inir' && ./setup install -y"`.
    - Garante permissões recursivas: `chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.config/inir"`.
  - **`interfaces/noctalia.sh`**:
    - Instalação declarativa via `install_packages_from_conf "${PACKAGES_DIR}/noctalia.conf"`.
  - **`interfaces/duxshell.sh`**:
    - Garante utilitários essenciais (`curl`, `git`, `kitty`) e renova sudo.
    - Executa o instalador headless oficial sob usuário real: `sudo -u "${REAL_USER}" bash -c "curl -fsSL https://install.duxlabs.dev | sh -s -- -c niri -t kitty -y --all-features"`.
    - Auto-reparo imediato de encapsulamento: restaura o template `config/system/pam_greetd.template` em `/etc/pam.d/greetd` para impedir que o pipeline do instalador da Dux Labs sobrescreva a integração com o keyring.
    - Assegura permissões do usuário em `.config` e `.local`.

### Módulo 07: Pós-Instalação e Validações (`07_post_install.sh`)

- Inicialização do cofre de credenciais PAM em `~/.local/share/keyrings/default` com conteúdo `login` (permissão `600`).
- Configuração declarativa do compositor ativo:
  - **Se Noctalia Shell (`SELECTED_INTERFACE="noctalia"`):**
    - **Se Umbriel:** Cria `~/.config/umbriel`, copia os arquivos de `${DESKTOP_DIR}/umbriel/*` (`config/desktop/umbriel/`) para `~/.config/umbriel/`. Se `IS_VM=true`, anexa (de forma idempotente, protegida por `grep -qF`) o bloco de software rendering e desativação de cursor de hardware ao final de `config.toml`. Valida via `sudo -u "${REAL_USER}" umbriel config validate`.
    - **Se Niri:** Cria `~/.config/niri`, copia `${DESKTOP_DIR}/niri/config.kdl` para `~/.config/niri/config.kdl`. Se `IS_VM=true`, anexa de forma idempotente o bloco `environment` de renderização por software. Valida via `sudo -u "${REAL_USER}" niri validate`.
  - **Se iNiR Shell (`SELECTED_INTERFACE="inir"`):** Não copia nem sobrescreve arquivos com os templates do Noctalia; assegura que `~/.config/niri/config.kdl` exista e injeta explicitamente o autostart `spawn-at-startup "inir" "run"` e, se `IS_VM=true`, o bloco `environment` de renderização por software, validando a sintaxe ao final com `niri validate`. Previne tela cinza vazia no Niri após o login.
  - **Se Dux Shell (`SELECTED_INTERFACE="duxshell"`):** Configura autostart do DMS via injeção de `spawn-at-startup "dms" "run"` no `config.kdl` do Niri caso não esteja presente, assegura variáveis de software rendering se `IS_VM=true`, e valida via `sudo -u "${REAL_USER}" niri validate`.
- Execução de `xdg-user-dirs-update` e `ensure_user_ownership` recursivo em `.config` e `.local`.
- Ativação defensiva do display manager (Greetd para Noctalia/DMS ou SDDM para iNiR) e target gráfico via `systemctl enable` (sem `--force`, que mascararia unidades inválidas).
- Se `INSTALL_NVIDIA=true` (e não for VM), executa `sudo akmods --force`.
- Registro do checklist de integridade no log (8 verificações finais, incluindo a presença do runtime Deno quando a interface selecionada for iNiR — a ausência é tratada como erro com `exit 1`).

---

## 5. TABELA FORMAL DE DECISÕES DEFENSIVAS E CASOS DE BORDA

| Decisão Arquitetural / Defensiva                                                        | Justificativa Técnica e Prevenção de Falhas                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| :-------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Infraestrutura como Código (IaC) e Eliminação de Pacotes Hardcoded**                  | Separação rigorosa entre lógica executável e dados declarativos. Nenhuma lista de pacotes é mantida chumbada em scripts `.sh`; todas as dependências residem em manifestos `.conf` isolados dentro de `config/`, garantindo 100% de auditabilidade, facilidade de manutenção e prevenção de regressões acidentais.                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **Sequenciamento Antecipado do Noctalia Greeter**                                       | A instalação declarativa prévia de `config/packages/noctalia.conf` no Módulo 04 antes de executar a autorização Polkit garante que os binários `noctalia-greeter` já estejam presentes no disco quando o comando `noctalia-greeter passwordless-sync enable` for acionado, prevenindo falha de comando inexistente durante a subida da stack gráfica.                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **Auto-reparo e Persistência do PAM Greetd pós-Instalador Dux**                         | O binário upstream `dankinstall` (Dux Installer, distribuído por `install.duxlabs.dev`) pode sobrescrever `/etc/pam.d/greetd` com configurações simplificadas sem suporte a chaveiro. O submódulo `modules/interfaces/duxshell.sh` reaplica o template defensivo `config/system/pam_greetd.template` garantindo posse `root:root`, permissão `644` e desbloqueio silencioso do `pam_gnome_keyring.so`.                                                                                                                                                                                                                                                                                                                                                                              |
| **Autorização do Noctalia Greeter (`passwordless-sync`)**                               | O diretório `/var/lib/noctalia-greeter` com posse de `greetd:greetd` e a execução de `noctalia-greeter passwordless-sync enable` autorizam formalmente via Polkit a sincronização bidirecional do papel de parede e temas do desktop com a tela de login sem exigir senha administrativa.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **Desativação preventiva de GDM / LightDM / Greetd**                                    | Atua como rede de segurança essencial para evitar conflitos de display manager caso o usuário reexecute o instalador (desativando instâncias do Greetd de testes anteriores) ou caso o script seja rodado sobre Fedora Workstation/Spins que contenham GDM/LightDM pré-instalados. Evita dois serviços de login competindo pelo mesmo DRM/KMS.                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Execução de `sudo -v` antecipado em `interfaces/inir.sh` e `interfaces/duxshell.sh`** | O timeout padrão de credenciais administrativas do `sudo` no Linux varia entre 5 e 15 minutos. Em etapas anteriores demoradas (como download de apps e codecs no Módulo 03), o timestamp pode expirar. Renovar explicitamente o timestamp com `sudo -v` antes de acionar scripts upstream garante que seus comandos internos com privilégios não pausem a execução em segundo plano esperando senha interativa.                                                                                                                                                                                                                                                                                                                                                                     |
| **Isolamento e verificação criptográfica do download do Deno**                          | No Fedora moderno, `/tmp` é montado como `tmpfs` em memória RAM, com restrições severas de inodes/blocos e tamanho limitado. Em downloads paralelos ou em máquinas virtuais com 2GB-4GB de RAM, extrair arquivos no `/tmp` provoca erro de _No space left on device_ (`curl: (23) Failure writing output to destination`). Baixar no `${REAL_HOME}` protege contra o esgotamento da partição temporária em memória. Adicionalmente, a arquitetura do binário é detectada via `uname -m` (x86_64/aarch64) e o pacote é validado contra o checksum SHA-256 oficial da release antes de ser instalado em `/usr/local/bin`, mitigando adulteração da cadeia de suprimento.                                                                                                              |
| **Instalação antecipada de aplicativos (fontes/Kitty/codecs) no Módulo 03**             | Instalar Kitty, fontes Google Noto e codecs antes da configuração do compositor e da shell garante que todas as dependências visuais, ícones e o emulador de terminal padrão já estejam persistidos no disco antes de a interface gráfica ser compilada, configurada ou validada.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **Templates Declarativos vs `/usr/share/doc`**                                          | A adoção de templates próprios na pasta do instalador elimina a dependência de arquivos de exemplo do sistema operacional (que sofrem com caminhos versionados no Fedora e causavam o erro de atalhos vazios `not bound`), garantindo que tanto o Niri quanto o Umbriel iniciem com mapeamento completo de atalhos, mouse e teclas Fn.                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Injeção Dinâmica de Variáveis de VM vs Templates Limpos**                             | Os arquivos em `config/desktop/` e `config/system/` são mantidos intencionalmente limpos e otimizados para Máquinas Físicas (Bare Metal). A injeção das variáveis de ambiente (`LIBGL_ALWAYS_SOFTWARE=1`, `WLR_NO_HARDWARE_CURSORS=1` e `hardware_cursor = false`) ocorre em tempo de execução via `07_post_install.sh` somente se `IS_VM=true`, protegida por guarda de idempotência (`grep -qF 'LIBGL_ALWAYS_SOFTWARE'`) que impede a duplicação do bloco em reexecuções — e, no caso do Umbriel, a criação de tabelas TOML repetidas que corromperia a configuração. Isso previne que computadores reais com GPU dedicada tenham sua aceleração desativada, ao mesmo tempo em que blinda máquinas virtuais contra telas pretas e fechamentos inesperados (_crashes_) do QtQuick. |
| **Isolamento de Templates por Shell**                                                   | A cópia dos templates do Umbriel e Niri ocorre estritamente quando `SELECTED_SHELL="noctalia"`, preservando a autonomia e configuração gerada pelo instalador nativo do iNiR e do DMS quando estes forem os escolhidos.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **Autostart e VM Flags do iNiR e DMS no Niri**                                          | O Módulo 07 assegura a injeção declarativa de `spawn-at-startup "inir" "run"` (para iNiR) ou `spawn-at-startup "dms" "run"` (para DMS), junto ao bloco `environment` de software rendering quando em VM no `config.kdl`, prevenindo telas pretas ou vazias pós-login.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **Exclusão e Remoção Defensiva do Alacritty (`compositors/niri.sh`)**                   | O pacote upstream do Niri pode trazer o Alacritty como dependência recomendada ou fraca. A exclusão nominal de `alacritty` (filtrado localmente antes do dnf, pois o dnf5 rejeita argumentos combinados com `--exclude`) aliada à remoção defensiva subsequente garante que apenas o Kitty permaneça como emulador de terminal oficial do sistema, sem quebrar as outras dependências normais e fracas do Niri.                                                                                                                                                                                                                                                                                                                                                                     |
| **Autorização Administrativa Temporária no Sudoers (com validação `visudo`)**           | A criação do drop-in `/etc/sudoers.d/99-fedora-installer-temp` com `trap` de autodestruição (EXIT/HUP/INT/TERM) elimina o problema de timeout de credenciais do sudo (5 minutos) durante etapas demoradas de compilação em modo não-interativo. O fluxo é endurecido: a regra é montada em `mktemp` fora do caminho final, validada com `sudo visudo -cf` antes de qualquer instalação (sintaxe inválida aborta sem tocar `/etc/sudoers`), instalada com `sudo install -m 0440 -o root -g root` e precedida da remoção de drop-in órfão de execuções anteriormente killadas (`kill -9`), prevenindo resquícios NOPASSWD persistentes no sistema.                                                                                                                                    |
| **Log de instalação fora de `/tmp` (XDG State Home)**                                   | O log é gravado em `${XDG_STATE_HOME:-~/.local/state}/fedora-multi-shell/install.log` em vez de um caminho previsível em `/tmp`, eliminando a superfície clássica de ataques de symlink em diretórios temporários compartilhados; o `log_init` ainda rejeita alvos que já existam como link simbólico.                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Bootstrap do repositório Terra com `--nogpgcheck` circunscrito**                      | A ausência de chave GPG no primeiro contato é uma limitação documentada do bootstrap oficial do Terra (Fyra Labs). O instalador restringe `--nogpgcheck` estritamente aos pacotes `terra-release`/`terra-gpg-keys` via `--repofrompath` dedicado; todos os pacotes seguintes (`noctalia`, `umbriel-nightly`, etc.) são verificados normalmente após a instalação das chaves. A falha de ambos os métodos de bootstrap é tratada como erro fatal explícito (sem falsos log de sucesso).                                                                                                                                                                                                                                                                                              |
| **Validação de entrada e verificação de versão alvo**                                   | Os menus nunca interpretam silenciosamente entradas inválidas: `ui_ask_choice`/`ui_ask_yn` rejeitam e reperguntam fora do conjunto válido. A release do Fedora detectada em runtime (`rpm -E %fedora`) é comparada com `TARGET_FEDORA_VERSION` (`config/settings.conf`), tornando a suposição de versão "Fedora 44" verificável em vez de implícita.                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Resiliência de Mirrors no Bootstrap (mestre direto + fastestmirror + retentativas)**  | O `mirrors.rpmfusion.org` faz steering geográfico via MirrorManager: se o mirror designado para a região do usuário estiver morto, todas as requisições caem no mesmo mirror inacessível (caso real: Brasil → mirror grego caído). O Módulo 00 agora: (1) habilita `fastestmirror` no DNF para priorizar o mirror de menor latência real; (2) baixa os release RPMs do RPM Fusion primeiro do servidor-mestre direto `download1.rpmfusion.org` (sem roleta), com retentativas na roleta e alternância IPv4 como fallback, instalando do arquivo local na Home do usuário; (3) pula o bootstrap se o RPM Fusion já estiver configurado (idempotência).                                                                                                                               |

---

## 6. CRITÉRIOS DE TESTE E VALIDAÇÃO

- [x] **Validação do Display Manager:** Serviços `sddm.service` ou `greetd.service` habilitados e integração com `pam_gnome_keyring.so` configurada no respectivo arquivo de PAM.
- [x] **Validação do Compositor:** Validação nativa com `niri validate` (para Niri) ou `umbriel config validate` (para Umbriel).
- [x] **Validação de Permissões:** Garantia de que `~/.config` e `~/.local` pertençam ao usuário real (`$USER:$USER`).
- [x] **Validação de Driver na VM:** Garantia de ausência de drivers proprietários NVIDIA quando em VM.
- [x] **Validação do Keyring e PAM:** Pacote `gnome-keyring-pam` instalado, ponteiro `default` com conteúdo `login` e permissão `600`.
- [x] **Validação de Runtimes:** Presença de Deno em `/usr/local/bin/deno` (provisionado com detecção de arquitetura e conferência de checksum SHA-256) e pacotes Python/C para compilações locais.
- [x] **Validação de IaC:** Todos os manifestos `.conf` isolados em `config/` validados com sintaxe de um pacote por linha e comentários temáticos limpos.
- [x] **Validação de Segurança Operacional:** Drop-in temporário de sudoers validado com `visudo -cf` antes da instalação, sem resquícios órfãos pós-interrupção, log gravado fora de `/tmp` (XDG State Home) e menus com entrada validada/reperguntada.
- [x] **Validação de Versão Alvo:** Release detectada (`rpm -E %fedora`) confrontada com `TARGET_FEDORA_VERSION`; divergência exige confirmação interativa explícita para prosseguir.
