# 🛡️ Segurança, Modelo de Ameaças e Blindagem da Cadeia de Suprimentos

Este documento estabelece o modelo conceitual e formal de ameaças do ecossistema **Fedora Multi-Shell**, detalhando a superfície de ataque em estações de trabalho Linux modernas, o ciclo de vida e a arquitetura do cofre de credenciais **oo7** (Secret Service em Rust), a análise comparativa de empacotamento (*RPM vs. Flatpak vs. AppImage*) e as mitigações implementadas no instalador para assegurar máxima integridade à cadeia de suprimentos (*Supply Chain Security*).

---

## 1. Modelo de Ameaças do Linux Desktop (Process Isolation vs. Shared UID)

### 1.1 A Fronteira de Segurança do Linux Tradicional
Em uma distribuição Linux padrão operando em modo mono-usuário interativo, todos os binários de usuário executam com o mesmo Identificador de Usuário (**UID 1000**). Sob o modelo clássico do POSIX:
- Qualquer processo executando como `UID 1000` possui permissão irrestrita de leitura, escrita e modificação sobre todo o diretório `$HOME` (`~/.bashrc`, `~/.ssh/`, `~/.config/`, `~/.local/share/`).
- Todos os processos do usuário compartilham o mesmo **Session D-Bus** (`/run/user/1000/bus`), permitindo que qualquer aplicação envie e intercepte mensagens IPC (*Inter-Process Communication*) voltadas a serviços de sessão.
- Em ambientes gráficos legados (X11), qualquer cliente podia registrar atalhos globais, espionar teclas pressionadas (*keylogging*) e injetar eventos de entrada em janelas de outros processos. O **Wayland** extinguiu esse vetor estrutural ao isolar estritamente o mapa de janelas e os dispositivos de entrada via compositor, mas não resolve o isolamento em nível de sistema de arquivos e barramento D-Bus entre processos nativos com o mesmo UID.

### 1.2 O Freedesktop Secret Service API (`org.freedesktop.secrets`)
O padrão Freedesktop Secret Service define uma especificação sobre o D-Bus para armazenamento seguro de senhas, chaves de API e tokens de autenticação por aplicações desktop.
- **Funcionamento:** O daemon escuta no barramento de sessão em `org.freedesktop.secrets` e armazena os segredos criptografados no disco (normalmente no arquivo `~/.local/share/keyrings/login.keyring`), derivando a chave-mestre a partir da senha de login do usuário.
- **Limitações Estruturais no Shared UID:** Qualquer processo nativo rodando sob o mesmo UID sem contenção pode se conectar diretamente ao barramento de sessão e requisitar segredos destravados ao Secret Service, a menos que haja mediação granular por portais XDG ou isolamento de namespaces.

---

## 2. Pilha de Credenciais oo7 no Fedora 45

### 2.1 Transição de GNOME Keyring para oo7-daemon em Rust
Historicamente, o Secret Service API era implementado pelo `gnome-keyring-daemon` escrito em C. A partir do **Fedora 45**, a distribuição adotou formalmente o ecossistema **oo7** (`oo7-daemon` e biblioteca `oo7`), desenvolvido integralmente em **Rust**:
- **Garantias de Memory Safety:** A implementação em Rust elimina por concepção classes críticas de vulnerabilidades recorrentes em daemons criptográficos em C, como *buffer overflows*, *use-after-free*, estouros de ponteiro e corrupção de memória sob concorrência.
- **Base de Dados Segura:** O `oo7` manipula nativamente a criptografia dos chaveiros sem depender de stubs estáticos ou hacks legados de inicialização.

### 2.2 oo7-portal e Proteção contra Aplicações Sandboxed
Aplicações confinadas (como navegadores ou ferramentas em Flatpak) não acessam o `org.freedesktop.secrets` diretamente no barramento do host. O `oo7` atua em conjunto com o `xdg-desktop-portal` (`org.freedesktop.portal.Secret`):
- O portal media o acesso: quando uma aplicação em Flatpak requisita ou salva um segredo, o portal solicita ao `oo7` um token encriptado vinculado à identidade exclusiva do aplicativo (`app-id`).
- Um Flatpak malicioso ou comprometido não pode listar ou ler segredos pertencentes a outros Flatpaks ou a aplicações do host.

### 2.3 O Ciclo de Vida do PAM e a Diretiva `auto_start`
O desbloqueio automático e transparente do cofre de credenciais durante a autenticação gráfica depende da integração entre o PAM (*Pluggable Authentication Modules*), o gerenciador de login (Greetd ou SDDM) e o socket do `oo7`:
1. **Fase `auth`:** O usuário insere suas credenciais na tela de login. O `pam_oo7.so` armazena temporariamente o token de autenticação (*authtok*) em memória protegida de processo.
2. **Fase `session`:** Quando o Greetd ou SDDM abre a sessão de usuário através de `session optional pam_oo7.so auto_start`, a diretiva `auto_start` instrui o módulo PAM a conectar-se imediatamente ao socket de domínio Unix do daemon (`/run/user/$UID/oo7-pam.sock`).
   - Se o daemon ainda não estiver ativo no momento da abertura da sessão, a diretiva `auto_start` comanda o disparo imediato do serviço, evitando que o cofre inicie bloqueado.
   - O token capturado no login destrava o chaveiro `login` instantaneamente, prevenindo a exibição do incômodo pop-up `gcr-prompter` ("Unlock Keyring") ao carregar a interface gráfica ou o navegador.

---

## 3. Análise Comparativa de Empacotamento: RPM vs. Flatpak vs. AppImage

Compreender o nível de isolamento de cada formato de empacotamento é indispensável para desenhar uma workstation defensiva:

| Vetor de Segurança / Formato | RPM / DEB (Nativo) | Flatpak (Flathub) | AppImage |
| :--- | :--- | :--- | :--- |
| **Sandbox de Processo** | ❌ Nenhuma (Acesso total ao host) |  Isolamento via Bubblewrap | ❌ Nenhuma por padrão |
| **Namespaces de Kernel** | ❌ Compartilha PID, Mount, Net |  Namespaces dedicados | ❌ Compartilha com o host |
| **Acesso a `$HOME`** |  Irrestrito a todos os arquivos | ⚠️ Restrito / Mediado por permissões |  Irrestrito a todos os arquivos |
| **Acesso a Dispositivos e Câmera** |  Acesso direto via `/dev/` |  Acesso mediado por XDG Portals |  Acesso direto ao `/dev/` |
| **Superfície de Ataque** | Crítica se o aplicativo for comprometido | Mínima (confinada ao container) | Crítica se o aplicativo for comprometido |

### 3.1 RPM (Nativo)
- **Vantagens:** Máximo desempenho, integração perfeita com aceleração de hardware (VA-API/Vulkan), consumo reduzido de memória e ligação nativa com compositores Wayland e bibliotecas do sistema.
- **Risco:** O binário executa com todos os direitos do usuário logado. Se uma vulnerabilidade de execução remota de código (RCE) ocorrer no navegador ou leitor de mídia empacotado em RPM, o atacante adquire acesso a arquivos de configuração, chaves SSH e dados locais do usuário.

### 3.2 AppImage: A Desmistificação da "Falsa Sandbox"
- Existe um equívoco comum no ecossistema Linux de presumir que AppImages são seguros por serem "portáteis".
- **Realidade Técnica:** Um AppImage é apenas um sistema de arquivos SquashFS montado em tempo de execução via FUSE que executa um binário nativo convencional. **Não há isolamento de kernel, nem restrição de acesso ao sistema de arquivos, nem mediação de chamadas de sistema.** Um AppImage malicioso possui exatamente a mesma capacidade de exfiltração de dados que um binário ELF comum.

### 3.3 Flatpak: O Padrão de Referência da Indústria
- O Flatpak utiliza utilitários do kernel Linux desenvolvidos para containers: **Bubblewrap**, cgroups, seccomp filters e namespaces (mount, IPC, PID, network).
- Toda comunicação com o hardware e com recursos do usuário (câmera, microfone, abertura de arquivos, notificações, segredos) é mediada por **Portais XDG** (*xdg-desktop-portal*), com prompts de consentimento explícito.
- É a recomendação oficial do Fedora Multi-Shell para navegadores secundários, reprodutores multimídia (ex: reprodutor Cine via Flatpak), clientes de mensagens e ferramentas proprietárias de terceiros.

---

## 4. Boas Práticas de Gestão de Senhas e Credenciais

Em consonância com as recomendações do CIS Benchmarks e princípios de Zero Trust no desktop:

1. **Evite o Preenchimento Nativo em Navegadores RPM:**
   - Navegadores como Brave, Chrome ou Firefox instalados via pacote nativo RPM armazenam chaves criptográficas atreladas ao Secret Service do desktop. Qualquer script ou utilitário executando no espaço do usuário poderia, em tese, consultar o barramento D-Bus para ler os registros do navegador.
2. **Adote Gerenciadores de Senhas Dedicados (Bitwarden / KeePassXC):**
   - Utilize cofres independentes com derivação de chave forte (Argon2id).
   - Configure **bloqueio automático por inatividade de memória** (ex: travar cofre após 15 minutos sem uso).
   - O cofre permanece criptografado na RAM quando inativo, impedindo que dumps de memória extraiam senhas em texto puro.
3. **Chaves SSH com Criptografia e Passphrase:**
   - O instalador provisiona o `ssh-agent` nativo do OpenSSH via socket activation do systemd (`/usr/lib/systemd/user/ssh-agent.socket`).
   - Mantenha suas chaves privadas protegidas por senha forte (`ssh-keygen -t ed25519 -a 100`). A senha é mantida em memória volátil de sessão, sem escrita em arquivos descriptografados no disco.

---

## 5. Mitigações de Cadeia de Suprimentos no Instalador

O instalador `fedora-multishell` foi integralmente blindado contra vetores clássicos de comprometimento de cadeia de suprimentos:

1. **Eliminação Absoluta de Invocação Remota `curl | sh`:**
   - A invocação remota e não-auditável da Dux Labs foi completamente removida de `modules/interfaces/duxshell.sh`.
   - Todos os pacotes da suite (`dms`, `dux-greeter`, `dsearch`, `dcal`) são declarados formalmente no manifesto auditável `config/packages/duxshell.conf` e instalados sob controle rigoroso do gerenciador DNF.
2. **Resolução Semântica Dinâmica de Releases Git:**
   - O submódulo `modules/interfaces/inir.sh` rejeita expressamente commits instáveis ou não testados da branch `main`.
   - Utiliza a rotina `security_checkout_latest_release` (`git tag -l --sort=-v:refname "v*" | head -n 1`), garantindo que apenas releases semânticas estáveis e assinadas pelos mantenedores sejam compiladas no sistema.
3. **Validação Criptográfica de Repositórios Externos:**
   - Para repositórios que distribuem chaves avulsas (como RPM Fusion), as chaves públicas de assinatura GPG são importadas e validadas defensivamente via `rpm --import` antes de qualquer transação.
   - Para o repositório Terra (Fyra Labs), adota-se o método oficial com `--nogpgcheck` estritamente circunscrito ao bootstrap de `terra-release` e `terra-gpg-keys` via `--repofrompath`, visto que a chave pública oficial é distribuída exclusivamente empacotada no `terra-gpg-keys`. Uma vez instaladas as chaves, todas as instalações subsequentes de pacotes são verificadas normalmente.
4. **Sudo Keep-Alive em Memória (Sem `NOPASSWD` em Disco):**
   - O antigo método de gravar um arquivo temporário em `/etc/sudoers.d/99-fedora-installer-temp` foi descontinuado.
   - O instalador executa a rotina `security_init_sudo_keepalive`, que valida as credenciais uma única vez com `sudo -v` e mantém o timestamp renovado na memória do kernel a cada 50 segundos, atrelado estritamente ao PID pai (`$$`). Ao finalizar ou sofrer interrupção (sinais `EXIT`, `INT`, `TERM`), o loop é encerrado automaticamente sem deixar privilégios abertos no disco.
5. **Prevenção de Ataques de Symlink e Poluição de `/tmp`:**
   - Logs de instalação são mantidos em `${XDG_STATE_HOME:-~/.local/state}/fedora-multi-shell/install.log`, recusando alvos que sejam links simbólicos.
   - Downloads volumosos e compilações ocorrem sob o disco persistente da Home do usuário, prevenindo esgotamento de memória em partições virtuais `tmpfs`.

