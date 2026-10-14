# 🌌 Fedora iNiR: Pure Wayland Workstation

Instalador modular, limpo e automatizado para transformar uma instalação mínima do **Fedora (Netinstall / Everything)** em uma workstation gráfica moderna baseada em:

* **Compositor Wayland:** [Niri](https://github.com/YaLTeR/niri) (Scrollable tiling Wayland compositor via COPR `yalter/niri`)
* **Desktop Shell:** [iNiR](https://github.com/snowarch/inir) (Shell moderna baseada em Quickshell e Material You via COPR `errornointernet/quickshell`)
* **Display Manager / Gerenciador de Login:** [SDDM](https://github.com/sddm/sddm) (nativamente integrado e estilizado pelo iNiR)
* **Emulador de Terminal & CLI:** [Kitty](https://sw.kovidgoyal.net/kitty/) (acelerado por GPU) + `fastfetch` (informações de sistema)
* **Compatibilidade X11:** `xwayland-satellite` (rootless isolado)
* **Theming / Material You:** `matugen` (gerador dinâmico de paletas de cores)
* **Runtimes & Multimídia:** Python 3.12, Deno runtime, `mpv` e `socat` (integração IPC do YouTube Music)
* **Navegador Web:** Brave Origin (sem telemetria, IA ou criptomoedas)
* **Loja de Apps:** GNOME Software (Loja gráfica nativa com integração ao Flathub e atualizações do sistema)
* **Reprodutor de Vídeo:** Cine (`io.github.diegopvlk.Cine` via Flatpak)

---

## 🏗️ Arquitetura Modular do Projeto

O instalador foi projetado seguindo as diretrizes de **Separação de Preocupações (SoC)** e **Idempotência**. Você pode customizar os pacotes instalados apenas editando os arquivos de texto na pasta `config/`, sem alterar nenhuma linha de código dos scripts:

```text
fedora-inir/
├── setup.sh                         # Ponto de entrada: validações, menu e orquestração
├── config/
│   ├── packages-base.conf           # Infraestrutura do sistema (Firmware, SDDM, dependências iNiR, Áudio, Portais)
│   ├── packages-apps.conf           # Aplicações de uso diário, codecs multimídia e fontes
│   ├── packages-flatpak.conf        # Lista declarativa de aplicativos Flatpak do Flathub
│   ├── packages-nvidia.conf         # Pilha proprietária de drivers e módulos NVIDIA
│   └── settings.conf                # Variáveis globais, repositórios e flags padrão
├── lib/
│   ├── ui.sh                        # Renderização do menu ANSI, banners e caixas visuais
│   ├── logger.sh                    # Registro em /tmp/fedora-inir-installer.log e traps de erro
│   └── utils.sh                     # Sudo keepalive, validação de não-root e permissões
├── modules/
│   ├── 00_repos.sh                  # Repositórios (COPRs Niri/Quickshell, RPM Fusion, Brave, Flathub)
│   ├── 01_system_hardware.sh        # Firmware, microcódigo de CPU, som e energia
│   ├── 02_gpu_drivers.sh            # Drivers Mesa abertos ou NVIDIA com akmods
│   ├── 03_display_stack.sh          # SDDM e integração PAM
│   ├── 04_compositor_shell.sh       # Deno provision, Niri, Quickshell, iNiR Shell e Portais XDG
│   ├── 05_desktop_apps.sh           # Apps de usuário, Brave Origin e Loja GNOME Software
│   └── 06_post_install.sh           # Configuração do Niri (config.kdl), iNiR autostart, ABNT2, ativação do SDDM e validações
└── templates/
    └── pam_sddm.template            # Configuração do Gnome Keyring no PAM para o SDDM
```

---

## 🚀 Guia de Instalação Passo a Passo

### 1. Preparação da Mídia (Fedora Netinstall)
1. Baixe a imagem ISO do **Fedora Everything (Netinstall)** no site oficial do Fedora.
2. Grave a imagem em um pendrive com o Fedora Media Writer, Rufus ou `dd`.
3. Inicie o instalador Anaconda:
   - Defina idioma e layout do teclado.
   - Configure o particionamento do disco.
   - Na tela de **Seleção de Programas (Software Selection)**:
     - Selecione **Minimal Install** (Instalação Mínima) ou **Fedora Custom Operating System**.
     - Se estiver em **Máquina Virtual**, veja a nota abaixo sobre os *Guest Agents*.
     - Se estiver em **Máquina Física**, desmarque todos os grupos opcionais para garantir uma instalação 100% limpa.
   - Crie o seu usuário comum e marque a opção para **torná-lo administrador (`wheel`)**.

> ### 📌 Nota para Instalação em Máquinas Virtuais (VMware / VirtualBox)
> O instalador já inclui preventivamente o pacote **`open-vm-tools`** em `config/packages-base.conf` e aplica automaticamente o isolamento de drivers de GPU e renderização quando você seleciona Máquina Virtual no menu interativo:
> 1. Redimensionamento automático da resolução ao maximizar a janela.
> 2. Compartilhamento fluido da área de transferência (Copiar e Colar entre o hospedeiro e a VM).
> 3. Captura e liberação de ponteiro estável.

---

### 2. Executando o Instalador

Após concluir a instalação básica e reiniciar no console tty com seu usuário comum:

```bash
# 1. Instale o git para clonar o repositório (ou use curl se preferir)
sudo dnf install -y git

# 2. Clone o instalador
git clone https://github.com/seu-usuario/fedora-inir.git
cd fedora-inir

# 3. Dê permissão de execução
chmod +x setup.sh modules/*.sh

# 4. Inicie o instalador como USUÁRIO COMUM (NÃO execute com sudo!)
./setup.sh
```

---

## ⚙️ Funcionalidades e Proteções Integradas

1. **Sudo Keepalive Automático:**
   O instalador valida suas credenciais uma única vez no início (`sudo -v`) e mantém um loop em segundo plano para renovar o timestamp do sudo enquanto os pacotes são baixados. Você não precisará ficar digitando senha no meio do download.

2. **Permissões Estritas no `$HOME`:**
   Todos os arquivos de configuração do usuário (`~/.config/niri/config.kdl`, `~/.config/inir`, pastas XDG, etc.) são criados e atribuídos exclusivamente ao seu usuário comum (`$USER:$USER`), impedindo que pastas fiquem bloqueadas por permissões de `root`.

3. **Provisionamento Defensivo de Runtimes (Deno, Python 3.12 e Cairo):**
   Para eliminar falhas de compilação do virtualenv do iNiR (`pycairo`/Meson) e erros de download do runtime do YouTube Music (`curl: (23) Failure writing output to destination`), o instalador:
   - Fornece previamente `python3.12`, `python3.12-devel`, `cairo-devel`, `cairo-gobject-devel` e `gobject-introspection-devel`.
   - Baixa e instala preventivamente o binário oficial do `deno` em `/usr/local/bin/deno` utilizando a pasta pessoal do usuário durante o download para não saturar limites de blocos/inodes na tmpfs do `/tmp`.
   - Instala `unzip`, `socat` e `mpv` para IPC de áudio sem falhas.

4. **Gerenciador de Login SDDM Robusto:**
   Diga adeus a telas pretas e problemas de permissões no display manager. O **SDDM** é instalado nativamente, tem o usuário configurado nos grupos de hardware (`video,render,input`), é forçado como gerenciador padrão via systemd e integra-se ao `pam_gnome_keyring.so` para desbloqueio automático de senhas.

5. **Injeção Segura no KDL do Niri:**
   A configuração do Niri (`~/.config/niri/config.kdl`) é configurada com autostart do iNiR (`spawn-at-startup "inir" "run"`), preservando a sintaxe declarativa KDL e criando backups automáticos (`.bak`).

6. **Tratamento de Secure Boot (NVIDIA):**
   Se você escolher instalar os drivers proprietários da NVIDIA, o script pausará e exibirá com destaque o alerta sobre a compilação via `akmods` e a necessidade de desativar o Secure Boot na BIOS/UEFI para evitar telas pretas.

7. **Suporte Transparente para Máquinas Virtuais:**
   Em máquinas virtuais, o script desativa automaticamente os drivers proprietários NVIDIA, ativa renderização por software (`LIBGL_ALWAYS_SOFTWARE=1`) e desativa flags conflitantes de hardware cursor, garantindo boot suave e mouse responsivo no VirtualBox e VMware.

---

## 📦 Modularidade de Aplicativos Flatpak

O projeto segue rigorosamente o princípio de **Separação de Preocupações (SoC)** e arquitetura declarativa. Nenhuma aplicação de usuário em sandbox fica hardcoded nos scripts shell:
* **Lista Declarativa Dedicada:** Todos os aplicativos Flatpak são gerenciados através do arquivo `config/packages-flatpak.conf`.
* **Facilidade de Expansão:** Para adicionar novos aplicativos Flatpak (por exemplo: Spotify, Discord, OBS Studio, Steam), basta inserir o ID do pacote em uma nova linha desse arquivo.
* **Zero Alteração em Código:** O instalador detecta e instala dinamicamente todas as entradas listadas via Flathub, sem que você precise mexer em nenhum script do repositório.

---

## 🖨️ Suporte Universal de Hardware e Impressão

### Suporte Universal de Hardware (Wi-Fi e Bluetooth)
Em instalações mínimas (Netinstall), o Fedora fraciona os pacotes de firmware por fabricante. O instalador adota o metagrupo oficial **`@hardware-support`** em conjunto com o daemon **`wpa_supplicant`**, garantindo reconhecimento imediato de adaptadores Wi-Fi e Bluetooth.

### Suporte Universal de Impressão (Plug-and-Play e Wi-Fi)
O sistema vem totalmente preparado para operar com qualquer fabricante de impressora (HP, Epson, Brother, Canon) em ambiente Wayland puro com `@printing`, `cups-browsed`, `avahi-daemon`, `system-config-printer-udev` e regras de firewall para mDNS/IPP.

---

## ⌨️ Atalhos de Teclado Nativos e Controle (Niri & iNiR)

O Niri fornece um modelo inovador de *scrollable tiling* com navegação horizontal contínua de colunas e janelas, perfeitamente complementado pelo iNiR Shell (Material You / Quickshell):

| Combinação de Teclas | Ação |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> / <kbd>Enter</kbd> | Abre o Terminal GPU (`kitty`) |
| <kbd>Super</kbd> + <kbd>Q</kbd> / <kbd>Super</kbd> + <kbd>C</kbd> | Fecha a janela em foco |
| <kbd>Super</kbd> + <kbd>H</kbd> / <kbd>L</kbd> ou <kbd>←</kbd> / <kbd>→</kbd> | Foca a coluna anterior / próxima (rolagem horizontal) |
| <kbd>Super</kbd> + <kbd>J</kbd> / <kbd>K</kbd> ou <kbd>↓</kbd> / <kbd>↑</kbd> | Foca a janela inferior / superior dentro da coluna |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> / <kbd>L</kbd> | Move a coluna atual para a esquerda / direita |
| <kbd>Super</kbd> + <kbd>1</kbd> a <kbd>9</kbd> | Alterna diretamente para a área de trabalho (workspace) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd> a <kbd>9</kbd> | Move a janela para a área de trabalho especificada |
| <kbd>Super</kbd> + <kbd>D</kbd> / <kbd>Super</kbd> + <kbd>Espaço</kbd> | Abre o Lançador de Aplicativos (iNiR Launcher / Fuzzel) |
| <kbd>Super</kbd> + <kbd>R</kbd> | Alterna entre larguras pré-definidas de coluna no Niri |
| <kbd>Super</kbd> + <kbd>F</kbd> | Alterna modo tela cheia (Fullscreen) |
| <kbd>Print</kbd> / <kbd>Super</kbd> + <kbd>Print</kbd> | Captura de tela interativa (`grim` + `slurp`) |
| *Painel iNiR Shell* | Controle visual e interativo de Volume, Brilho, Wi-Fi, Bluetooth, Bateria e Notificações |

---

## 🗓️ Compatibilidade e Fontes de Pacotes

O instalador utiliza fontes e repositórios padronizados:

- **RPM Fusion (Free e Nonfree):** Codecs multimídia e drivers NVIDIA akmods.
- **COPRs Oficiais da Stack:**
  - `yalter/niri`: Pacotes mais recentes e otimizados do compositor Niri.
  - `errornointernet/quickshell`: Framework e runtime QML para desktop shells modernas.
- **Brave Software RPM Repository:** Navegador Brave oficial.
- **Flathub:** Repositório universal Flatpak.

---

## 🔑 Gerenciamento de Credenciais (Chaveiro / Keyring)

O instalador configura automaticamente o subsistema de credenciais para garantir uma experiência de autenticação transparente, silenciosa e segura:

* **Módulo PAM (`gnome-keyring-pam`):** Intercepta as credenciais digitadas no SDDM e desbloqueia silenciosamente o cofre canônico `login.keyring` no início da sessão gráfica.
* **Ponteiro Canônico (`default` -> `login`):** Aplicações (como Brave, navegadores Chromium, Git Credential Manager e Wi-Fi) solicitam via D-Bus (`org.freedesktop.Secrets`) o chaveiro configurado como `default`. Com `~/.local/share/keyrings/default` pré-configurado contendo `login` (permissão `600`, diretório `700`), todas as aplicações são direcionadas ao chaveiro que o PAM já destrancou na inicialização.

---

## 🔍 Solução de Problemas e Auditoria

* **Log Detalhado:** O histórico completo de execução com timestamps é gravado em:
  ```bash
  cat /tmp/fedora-inir-installer.log
  ```
* **Runtimes e YouTube Music:** Python 3.12, pacotes de desenvolvimento C (`cairo-devel`), Deno e utilitários IPC (`socat`, `mpv`) são instalados de forma automatizada pelo script para prevenir qualquer falha na montagem de widgets multimídia do iNiR.
* **Verificação do Display Manager:**
  ```bash
  sudo systemctl status sddm.service
  ```
* **Validação do Compositor Niri:**
  Verifique a sintaxe e a integridade do arquivo `~/.config/niri/config.kdl` executando o validador oficial do Niri:
  ```bash
  niri validate
  ```
