# PLANO DE IMPLEMENTAÇÃO E ESPECIFICAÇÃO TÉCNICA

## Projeto: Fedora Minimal (Netinstall) → Pure Wayland Workstation

**Stack Gráfica Modular:**
- **Compositores Suportados:**
  - **Niri** (`yalter/niri` via COPR): Scrollable-tiling Wayland compositor com rolagem horizontal contínua de colunas e janelas.
  - **Umbriel** (`umbriel-nightly` via Repositório Terra do Fyra Labs): Compositor Wayland com rolagem contínua de janelas (horizontal e vertical), além de múltiplos modos de exibição dinâmicos (Dwindle e Master).
- **Desktop Shells Suportadas:**
  - **iNiR Shell** (`snowarch/inir` via `quickshell`): Shell moderna baseada em Quickshell, C++/Qt e theming dinâmico Material You. Utiliza exclusivamente o compositor Niri.
  - **Noctalia Shell** (`noctalia` via pacote nativo Fedora): Interface gráfica desktop nativa em C++/Qt. Permite utilizar tanto o compositor Niri quanto o compositor Umbriel.
- **Display Manager:** **SDDM** (`sddm` nativo com integração e desbloqueio do PAM GNOME Keyring).

**Público-Alvo:** Desenvolvedor / Modelo de IA Gerador de Código  
**Versão Base Alvo:** Fedora 44 (x86_64)

---

## 1. DIRETRIZES DE ENGENHARIA E ARQUITETURA MODULAR

O script de instalação é estruturado estritamente sob os padrões de **Arquitetura em Camadas (Layered Architecture)**, **Separação de Preocupações (SoC)** e **Idempotência**.

A nova orquestração em camadas garante que toda a base do sistema e as ferramentas de usuário (incluindo emulador de terminal Kitty, fontes tipográficas, visualizadores e codecs) sejam provisionadas no disco antes da camada de interface gráfica e compositores ser configurada.

### 1.1 Árvore Estrutural do Projeto

```text
fedora-inir/
├── setup.sh                         # Ponto de entrada: validações, menu interativo pt-BR e orquestração
├── config/
│   ├── packages-base.conf           # Infraestrutura base do sistema (Firmware, Áudio PipeWire, open-vm-tools, XDG)
│   ├── packages-apps.conf           # Aplicações essenciais de usuário (Kitty, fontes, codecs, visualizadores)
│   ├── packages-flatpak.conf        # Lista declarativa de aplicativos Flatpak do Flathub
│   ├── packages-nvidia.conf         # Pilha proprietária de drivers e módulos do kernel NVIDIA (akmods)
│   └── settings.conf                # Variáveis globais (repositórios, versões, flags de ambiente)
├── lib/
│   ├── ui.sh                        # Renderização visual ANSI (banners limpos, caixas temáticas, prompts enxutos)
│   ├── logger.sh                    # Registro centralizado (/tmp/fedora-inir-installer.log) e tratamento de erros
│   └── utils.sh                     # Utilitários (checagem de não-root, sudo keepalive, permissões seguras)
├── modules/
│   ├── 00_repos.sh                  # Repositórios universais (RPM Fusion, Brave, Flathub) e condicionais (COPRs, Terra)
│   ├── 01_system_hardware.sh        # Firmware, microcódigo de CPU, PipeWire, rede e energia (Tuned)
│   ├── 02_gpu_drivers.sh            # Drivers gráficos (Mesa aberto ou NVIDIA com akmods e RTD3)
│   ├── 03_desktop_apps.sh           # Camada de Usuário: Kitty, fontes, codecs, Brave Origin, Flatpaks e Loja GNOME
│   ├── 04_display_stack.sh          # Camada de Display Manager: SDDM, permissões de hardware e PAM Keyring
│   ├── 05_compositor.sh             # Roteador/Dispatcher de Compositor Wayland (Padrão Strategy)
│   │   └── compositors/
│   │       ├── niri.sh              # Submódulo: Niri, xwayland-satellite, portais GNOME/GTK e niri-portals.conf
│   │       └── umbriel.sh           # Submódulo: Umbriel Nightly, xwayland-satellite e portais Umbriel/GTK
│   ├── 06_desktop_shell.sh          # Roteador/Dispatcher de Desktop Shell (Padrão Strategy)
│   │   └── shells/
│   │       ├── inir.sh              # Submódulo: Deno (/usr/local/bin), sudo -v antecipado, clone, ./setup install -y
│   │       └── noctalia.sh          # Submódulo: Instalação do pacote nativo Fedora 'noctalia'
│   └── 07_post_install.sh           # Configuração de autostart, ABNT2, VM flags, validação de configs e ativação do SDDM
└── templates/
    └── pam_sddm.template            # Configuração modelo de referência para o PAM do SDDM
```

### 1.2 Regras Estritas de Programação Shell

1. **Defensividade:** Todos os scripts rodam com `set -euo pipefail`.
2. **Execução sem Root Direto:** O script deve recusar ser executado diretamente com `sudo ./setup.sh`. Ele é iniciado pelo usuário comum (`./setup.sh`) e invoca `sudo` apenas onde necessário.
3. **Idempotência:** A reexecução do script (ou de módulos individuais) não deve duplicar linhas em arquivos de configuração (`grep -qF` antes de inserir).
4. **Isolamento Declarativo:** Listas em `config/` contém um pacote ou identificador por linha, ignorando comentários e linhas em branco.

---

## 2. MATRIZ DE OPÇÕES SUPORTADAS E COMPOSITORES

O instalador suporta as seguintes combinações de ambiente gráfico:

| Desktop Shell | Compositor Wayland | Repositórios Necessários | Descrição e Paradigma de Janelas |
| :--- | :--- | :--- | :--- |
| **iNiR Shell** | **Niri** | COPR `yalter/niri`<br>COPR `errornointernet/quickshell` | Shell moderna inspirada em Material You rodando sobre Niri com rolagem horizontal infinita de colunas e janelas. |
| **Noctalia Shell** | **Niri** | COPR `yalter/niri` | Shell nativa em C++/Qt sobre Niri, aliando a estética de desktop tradicional/moderna à rolagem horizontal contínua de janelas. |
| **Noctalia Shell** | **Umbriel** | Repositório Terra (Fyra Labs) | Shell nativa em C++/Qt sobre Umbriel, compositor Wayland dinâmico com suporte a rolagem contínua (horizontal e vertical) e múltiplos modos de janelas (Dwindle e Master). |

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
1. **SELEÇÃO DO AMBIENTE DE INSTALAÇÃO:** `[1] Máquina Física` ou `[2] Máquina Virtual`. Prompt: `Escolha uma opção: ` (Enter assume `1`).
2. **SELEÇÃO DA INTERFACE GRÁFICA (DESKTOP SHELL):** `[1] iNiR Shell` ou `[2] Noctalia Shell`. Prompt: `Escolha uma opção: ` (Enter assume `1`).
   - Se `Noctalia Shell`: exibe sub-pergunta de compositor `[1] Niri` ou `[2] Umbriel`. Prompt: `Escolha uma opção: ` (Enter assume `1`).
   - Se `iNiR Shell`: fixa automaticamente o compositor como `niri`.
3. **DRIVER DE VÍDEO DEDICADO (NVIDIA):** Apenas se Máquina Física. Prompt: `Deseja instalar os drivers proprietários da NVIDIA? [s/N]: ` (Enter assume `N`).
4. **CONFIGURAÇÃO DE TECLADO:** Prompt: `Deseja configurar o padrão Brasileiro ABNT2 (com tecla ç)? [S/n]: ` (Enter assume `S`).
5. **RESUMO DAS DEFINIÇÕES DA SESSÃO:** Exibe Ambiente, Interface Gráfica, Compositor, GPU e Teclado. Prompt: `Deseja iniciar a instalação com estas definições? [S/n]: ` (Enter assume `S`).
6. **PROMPT DE CONCLUSÃO:** `Deseja reiniciar o sistema agora? [S/n]: ` (Enter assume `S` e dispara `sudo reboot`).

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
    "06_desktop_shell.sh"
    "07_post_install.sh"
)
```

### Módulo 00: Repositórios e Fontes Condicionais (`00_repos.sh`)
- Repositórios universais: RPM Fusion Free e Nonfree, Brave Browser e Flathub.
- Repositórios condicionais:
  - Se `SELECTED_COMPOSITOR == "niri"`: ativa COPR `yalter/niri`.
  - Se `SELECTED_SHELL == "inir"`: ativa COPR `errornointernet/quickshell`.
  - Se `SELECTED_COMPOSITOR == "umbriel"`: ativa o repositório Terra do Fyra Labs (`terra-release` e `terra-gpg-keys`).
- Atualização e sincronização via `dnf upgrade --refresh -y`.

### Módulo 01: Infraestrutura de Hardware e Áudio (`01_system_hardware.sh`)
- Microcódigo de processadores (Intel/AMD).
- Instalação dos pacotes de infraestrutura (`config/packages-base.conf`), serviços de som (PipeWire/WirePlumber), perfis de energia (`tuned`), Bluetooth, UDisks e impressão.

### Módulo 02: Drivers Gráficos e GPU (`02_gpu_drivers.sh`)
- Em VM: bypass imediato para aceleração por software e compatibilidade com hypervisors.
- Em Bare Metal: instalação da aceleração aberta Mesa DRI/Vulkan/VA-API e switcheroo-control. Se NVIDIA for selecionado, instalação de `akmod-nvidia` e serviços RTD3.

### Módulo 03: Camada de Aplicativos do Usuário (`03_desktop_apps.sh`)
- Swap `ffmpeg-free` -> `ffmpeg`.
- Instalação de ferramentas do usuário (`kitty`, `fastfetch`, `nautilus`, visualizadores GTK4, utilitários multimídia, fontes `google-noto-*`).
- Instalação do Brave Origin, Loja Nativa GNOME Software com integração Flathub e Flatpaks declarativos (`config/packages-flatpak.conf`).
- Garante que a tipografia e o Kitty já existam no disco antes de a interface gráfica ser configurada.

### Módulo 04: Camada de Display Manager (`04_display_stack.sh`)
- **Se `SELECTED_SHELL == "noctalia"` (Greetd + Noctalia Greeter):**
  - Instalação de `greetd`, `greetd-selinux`, `noctalia-greeter` e `gnome-keyring-pam`.
  - Configuração do diretório de estado `/var/lib/noctalia-greeter` (posse `greetd:greetd`).
  - Execução de `noctalia-greeter passwordless-sync enable "${REAL_USER}"` para autorização nativa Polkit da sincronização de aparência sem senha.
  - Atribuição dos grupos de hardware `video,render,input` ao usuário `greetd`.
  - Configuração do `/etc/greetd/config.toml` (com flags defensivas de software rendering para VM se aplicável).
  - Configuração de integração PAM em `/etc/pam.d/greetd` com `pam_gnome_keyring.so` para desbloqueio silencioso do cofre de senhas no login.
- **Se padrão (`sddm`):**
  - Instalação do `sddm` e `gnome-keyring-pam`.
  - Atribuição dos grupos de hardware `video,render,input` ao usuário `sddm`.
  - Configuração de integração PAM em `/etc/pam.d/sddm` com `pam_gnome_keyring.so` para desbloqueio silencioso do cofre de senhas no login.

### Módulo 05: Roteador de Compositor Wayland (`05_compositor.sh`)
- Instalação de utilitários comuns: `git`, `polkit`, `gnome-keyring`, `swaylock`.
- Despacha a execução para o submódulo correspondente:
  - **`compositors/niri.sh`**: Instala `niri`, `xwayland-satellite`, `xdg-desktop-portal-gnome`, `xdg-desktop-portal-gtk` e configura `/etc/xdg/xdg-desktop-portal/niri-portals.conf`.
  - **`compositors/umbriel.sh`**: Instala `umbriel-nightly`, `xwayland-satellite`, `xdg-desktop-portal-umbriel-nightly`, `xdg-desktop-portal-gtk`.

### Módulo 06: Roteador de Desktop Shell (`06_desktop_shell.sh`)
- Despacha a execução para o submódulo correspondente:
  - **`shells/inir.sh`**:
    - Instala `quickshell`.
    - Provisiona defensivamente o binário oficial do Deno em `/usr/local/bin/deno` baixado em `${REAL_HOME}`.
    - Executa `sudo -v` imediatamente antes do instalador para renovar o timestamp administrativo.
    - Clona `https://github.com/snowarch/inir.git` para `${REAL_HOME}/.config/inir`.
    - Executa de forma não-interativa sob o usuário real: `sudo -u "${REAL_USER}" bash -c "cd '${REAL_HOME}/.config/inir' && ./setup install -y"`.
    - Garante permissões recursivas: `chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.config/inir"`.
  - **`shells/noctalia.sh`**:
    - Instala o pacote nativo `noctalia` via DNF.

### Módulo 07: Pós-Instalação e Validações (`07_post_install.sh`)
- Inicialização do cofre de credenciais PAM em `~/.local/share/keyrings/default` com conteúdo `login` (permissão `600`).
- Configuração do compositor ativo:
  - **Se Niri:** Configura `~/.config/niri/config.kdl` com autostart da shell selecionada (`spawn-at-startup "inir" "run"` ou `spawn-at-startup "noctalia"`), layout ABNT2 (`layout "br"`) e flags de VM se aplicável. Valida com `sudo -u "${REAL_USER}" niri validate`.
  - **Se Umbriel:** Configura `~/.config/umbriel/config.toml` com autostart de `noctalia`, layout ABNT2 (`layout = "br"`) e cursor de VM (`hardware_cursor = false`). Valida com `sudo -u "${REAL_USER}" umbriel config validate`.
- Execução de `xdg-user-dirs-update` e `chown -R` recursivo em `.config` e `.local`.
- Ativação defensiva do display manager:
  ```bash
  sudo systemctl disable gdm lightdm greetd 2>/dev/null || true
  sudo systemctl enable --force sddm.service
  sudo systemctl set-default graphical.target
  ```
- Se `INSTALL_NVIDIA=true`, executa `sudo akmods --force`.
- Registro do checklist de integridade no log.

---

## 5. TABELA FORMAL DE DECISÕES DEFENSIVAS E CASOS DE BORDA

| Decisão Arquitetural / Defensiva | Justificativa Técnica e Prevenção de Falhas |
| :--- | :--- |
| **Autorização do Noctalia Greeter (`passwordless-sync`)** | O diretório `/var/lib/noctalia-greeter` com posse de `greetd:greetd` e a execução de `noctalia-greeter passwordless-sync enable` autorizam formalmente via Polkit a sincronização bidirecional do papel de parede e temas do desktop com a tela de login sem exigir senha administrativa. |
| **Desativação preventiva de GDM / LightDM / Greetd** | Atua como rede de segurança essencial para evitar conflitos de display manager caso o usuário reexecute o instalador (desativando instâncias do Greetd de testes anteriores) ou caso o script seja rodado sobre Fedora Workstation/Spins que contenham GDM/LightDM pré-instalados. Evita dois serviços de login competindo pelo mesmo DRM/KMS. |
| **Execução de `sudo -v` antecipado em `shells/inir.sh`** | O timeout padrão de credenciais administrativas do `sudo` no Linux varia entre 5 e 15 minutos. Em etapas anteriores demoradas (como download de apps e codecs no Módulo 03), o timestamp pode expirar. Renovar explicitamente o timestamp com `sudo -v` antes de acionar `./setup install -y` do iNiR garante que seus comandos internos com privilégios não pausam a execução em segundo plano para pedir senha interativamente. |
| **Isolamento do download do Deno na Home em vez do `/tmp`** | No Fedora moderno, `/tmp` é montado como `tmpfs` em memória RAM, com restrições severas de inodes/blocos e tamanho limitado. Em downloads paralelos ou em máquinas virtuais com 2GB-4GB de RAM, extrair arquivos no `/tmp` provoca erro de *No space left on device* (`curl: (23) Failure writing output to destination`). Baixar no `${REAL_HOME}` protege contra o esgotamento da partição temporária em memória. |
| **Distinção entre layout ABNT2 e o idioma nativo das shells** | O parâmetro `layout "br"` injetado no bloco `xkb` do Niri ou no `[input.keyboard]` do Umbriel afeta exclusivamente a tabela física de mapeamento dos scancodes do hardware (viabilizando a tecla `Ç`, `~`, `^` e acentuações do padrão brasileiro), mantendo total independência do idioma das interfaces gráficas ou widgets (que permanecem em inglês nativo). |
| **Instalação antecipada de aplicativos (fontes/Kitty/codecs) no Módulo 03** | Instalar Kitty, fontes Google Noto e codecs antes da configuração do compositor e da shell garante que todas as dependências visuais, ícones e o emulador de terminal padrão já estejam persistidos no disco antes de a interface gráfica ser compilada, configurada ou validada. |

---

## 6. CRITÉRIOS DE TESTE E VALIDAÇÃO

- [x] **Validação do SDDM:** Serviço `sddm.service` habilitado no systemd e integração com `pam_gnome_keyring.so` presente em `/etc/pam.d/sddm`.
- [x] **Validação do Compositor:** Validação nativa com `niri validate` (para Niri) ou `umbriel config validate` (para Umbriel).
- [x] **Validação de Permissões:** Garantia de que `~/.config` e `~/.local` pertençam ao usuário real (`$USER:$USER`).
- [x] **Validação de Driver na VM:** Garantia de ausência de drivers proprietários NVIDIA quando em VM.
- [x] **Validação do Keyring e PAM:** Pacote `gnome-keyring-pam` instalado, ponteiro `default` com conteúdo `login` e permissão `600`.
- [x] **Validação de Runtimes:** Presença de Deno em `/usr/local/bin/deno` e pacotes Python/C para compilações locais.
