# 🚀 Modificações, Otimizações e Blindagem do iNiR Shell

Este documento técnico detalha formalmente todas as modificações arquiteturais, otimizações de memória RAM, blindagens defensivas e saneamento de pacotes aplicados sobre o desktop shell **iNiR** (`snowarch/inir`) no projeto **Fedora Multi-Shell**.

---

## 1. 🏛️ Motivação Arquitetural e Convivência Multi-Shell

### 1.1 Diferenças entre o Instalador Upstream e o Fedora Multi-Shell
O instalador original do iNiR (`./setup install -y`) foi projetado sob a premissa de posse exclusiva do sistema operacional e do compositor **Niri**, assumindo que o usuário utilizará unicamente o iNiR como ambiente desktop.

No ecossistema **Fedora Multi-Shell**, o paradigma adotado é o **Multi-Shell Acumulativo e Idempotente**, permitindo a coexistência pacífica e a alternância contínua entre:
- **Noctalia Shell** (Niri ou Umbriel)
- **Dux Shell / DMS** (Niri)
- **iNiR Shell** (Niri)

### 1.2 O Problema do `rsync --delete` no Upstream
O script `./setup install -y` do iNiR executa internamente uma sincronização destrutiva com flag `--delete` contra o diretório `~/.config/niri/`.
Em ambientes onde o Noctalia ou o Dux Shell já foram provisionados, essa operação do instalador do iNiR apaga silenciosamente:
- `~/.config/niri/shells/noctalia.kdl`
- `~/.config/niri/shells/duxshell.kdl`

Como consequência, ao tentar logar posteriormente na sessão do Noctalia (`noctalia-niri.desktop`) ou do Dux Shell (`duxshell-niri.desktop`), o compositor Niri não encontra o KDL isolado e cai no arquivo de fallback genérico do Fedora (`/etc/niri/config.kdl` com Waybar padrão e atalhos de fábrica), resultando em sessões órfãs ou quebradas.

### 1.3 Blindagem Aplicada no Módulo 07 (`07_post_install.sh`)
Para blindar a arquitetura contra exclusões destrutivas, o **Módulo 07** executa uma rotina mandatória de sincronização cumulativa e auto-reparo após a execução de qualquer interface:
1. Inspeciona as sessões declaradas em `/usr/share/wayland-sessions/` (`noctalia-niri.desktop`, `duxshell-niri.desktop`, `inir-niri.desktop`) e a interface selecionada em tempo de execução.
2. Restaura atomicamente os KDLs declarativos correspondentes a partir de `config/desktop/compositors/niri/shells/` para `~/.config/niri/shells/`.
3. Caso o ambiente detectado seja uma Máquina Virtual (`IS_VM=true`), reinsere defensivamente os parâmetros de renderização por software (`LIBGL_ALWAYS_SOFTWARE=1`, `WLR_NO_HARDWARE_CURSORS=1` e `hardware-cursor false`) com proteção de idempotência.
4. Garante as permissões e posse de `~/.config/niri` para o usuário real.

Desta forma, independentemente da ordem em que as interfaces forem instaladas ou reinstaladas, nenhuma sessão Wayland perde sua integridade funcional.

---

## 2. ⚡ Diagnóstico e Resolução do Consumo de Memória RAM (Redução do Idle de 2 GB)

### 2.1 Diagnóstico do Consumo Excessivo
Durante a instalação padrão do iNiR, o script upstream puxa dezenas de dependências opcionais do ecossistema KDE Plasma e suítes de áudio/vídeo. Em repouso (*idle*), o consumo de memória RAM do sistema atingia aproximadamente **2,0 GB a 2,4 GB**, degradando o desempenho principalmente em máquinas virtuais ou computadores com recursos moderados (4 GB a 8 GB de RAM).

Os principais responsáveis identificados pelo gasto de memória e poluição de processos foram:
- **`kf6-baloo` (KDE Baloo File Indexer):** Indexador contínuo em segundo plano que aloca entre 300 MB e 700 MB de RAM em repouso e realiza leitura intensiva de I/O em disco.
- **`easyeffects` e plugins LV2/LSP:** Daemon residente de processamento de áudio que consome cerca de 200 MB de RAM e ciclos constantes de CPU mesmo sem efeitos ativos.
- **`gnome-keyring`:** Conflito pelo barramento D-Bus do Secret Service com o `oo7-daemon` nativo do Fedora 45, mantendo dois daemons de keyring redundantes em memória.
- **`xwaylandvideobridge`:** Criação de janelas fantasmas capturadas indevidamente pelo Niri e consumo residual de memória.
- **`blueman`, `plasma-systemsettings` e `plasma-systemmonitor`:** Ferramentas gráficas redundantes com daemons e notificadores residentes.

### 2.2 Saneamento Cirúrgico e Economia Obtida
Com o saneamento implementado em `modules/interfaces/inir.sh`, os pacotes conflitantes são desinstalados e seus serviços de usuário são mascarados (`systemctl --user mask`). O consumo de memória RAM em repouso cai para a faixa de **~600 MB a 800 MB**, representando uma economia de **mais de 1,2 GB de RAM livre**.

---

## 3. 🔍 Guia Transparente dos Utilitários Removidos

A tabela abaixo documenta detalhadamente cada utilitário saneado, a justificativa técnica, os cenários em que são dispensáveis ou necessários e as instruções completas de restauração para o usuário:

| Utilitário / Pacote | O que é | Por que foi removido | Quando NÃO é necessário | Quando É necessário | Como Reinstalar (Fedora 45) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **XWayland Video Bridge** (`xwaylandvideobridge`) | Ponte de captura de tela X11 para compositores Wayland. | O Niri é um compositor tiling e captura a janela invisível do bridge como um bloco opaco (quadrado azul/cinza) no canto da tela. | Se você compartilha tela no Discord, Zoom ou Meet via navegadores modernos (Brave/Chrome) ou clientes Wayland nativos (Vesktop). | Se você utiliza estritamente o cliente legado oficial do Discord ou Zoom empacotado puramente para X11 e precisa transmitir telas individuais. | `sudo dnf install -y xwaylandvideobridge` |
| **EasyEffects** (`easyeffects`) | Processador e equalizador avançado de efeitos de áudio para PipeWire. | Pesa ~200 MB de RAM, carrega dezenas de plugins Calf/LSP e o iNiR gerencia o volume e nós de áudio nativamente via PipeWire. | Para uso cotidiano de áudio: ouvir músicas, assistir vídeos, jogar ou chamadas com controle padrão de volume. | Se você necessita de calibração fina de microfone (compressor/noise gate agressivo) ou equalizador paramétrico de 32 bandas. | `sudo dnf install -y easyeffects lsp-plugins-lv2` |
| **Blueman** (`blueman`) | Gerenciador gráfico de conexões Bluetooth em GTK. | O iNiR, o Noctalia e o Dux gerenciam conexões, pareamento e status Bluetooth nativamente via QML/BlueZ. | Para fones de ouvido Bluetooth, caixas de som, teclados e mouses modernos com pareamento SSP/PIN padrão. | Para pareamento de dispositivos legados que exijam PINs raros ou transferência manual de arquivos via protocolo OBEX. | `sudo dnf install -y blueman` |
| **KDE Baloo** (`kf6-baloo`) | Indexador semântico de arquivos em segundo plano do KDE. | O gerenciador de arquivos padrão da workstation é o Nautilus 51 (que usa o indexador Tracker/GNOME integrado); o Baloo consome de 300 a 700 MB de RAM inutilmente. | Em qualquer fluxo de trabalho tradicional no Fedora Multi-Shell. | Apenas se você instalar e adotar o Dolphin como gerenciador principal e depender da busca semântica do KDE. | `sudo dnf install -y kf6-baloo && balooctl6 enable` |
| **GNOME Keyring** (`gnome-keyring`) | Provedor legado de Secret Service do GNOME. | No Fedora 45, o provedor oficial é o `oo7-daemon` integrado ao `pam_oo7`. O `gnome-keyring` causa disputas pelo Secret Service e pop-ups residuais. | Sempre (o Nautilus 51 usa `libsecret` e comunica-se de forma 100% nativa com o `oo7`). | Nunca no Fedora 45 moderno com a stack oo7 homologada. | `sudo dnf install -y gnome-keyring` |
| **Systemsettings & Systemmonitor** (`systemsettings`, `plasma-systemmonitor`, `ksysguard`) | Centrais de configurações e monitores de tarefas do KDE Plasma. | O iNiR possui sua própria central de configurações gráfica (*Control Center*) e ferramentas nativas de monitoramento de sistema. | Para toda a navegação e ajustes do ecossistema do iNiR e compositores Wayland. | Se você deseja especificamente a interface de gráficos e métricas de hardware do KDE. | `sudo dnf install -y systemsettings plasma-systemmonitor` |

---

## 4. 🎨 Ocultação de Menus de Configuração Estética (`NoDisplay=true`)

Para manter a integridade visual dos aplicativos Qt5/Qt6 com estilo transparente *Material You*, os utilitários de tema **Kvantum Manager** (`kvantummanager`) e **Qt6ct** (`qt6ct`) são mantidos instalados no sistema. 

No entanto, suas entradas no lançador de aplicações são suprimidas através da adição de `NoDisplay=true` nos respectivos arquivos `.desktop` em `~/.local/share/applications/`. Isso evita poluir o menu principal de programas com telas de configuração avançada que já são coordenadas automaticamente pelo instalador e pelo motor de cores do iNiR.

---

## 5. 🛡️ Preservação Obrigatória do Diretório `~/inir-backup`

Durante o provisionamento, o instalador upstream do iNiR pode criar um diretório denominado `~/inir-backup` na raiz da pasta pessoal do usuário, contendo cópias de segurança de dotfiles preexistentes.

**Diretriz Canônica do Fedora Multi-Shell:**
- O instalador **NÃO** move, altera ou apaga o diretório `~/inir-backup`.
- O diretório permanece intocado na Home para que o próprio usuário tenha total transparência, soberania e autonomia para inspecionar, restaurar ou excluir seus arquivos de backup no momento em que desejar.

