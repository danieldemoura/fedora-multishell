# 🏛️ Diretrizes de Arquitetura, Engenharia e Boas Práticas

Este documento estabelece as regras de design, engenharia de software e padrões de programação defensiva adotados no projeto **Fedora Multi-Shell**.

Todas as futuras contribuições humanas e comandos executados por **Agentes de Inteligência Artificial** devem seguir estritamente as diretrizes abaixo.

---

## 1. Princípios de Arquitetura de Software

### 1.1 Separação de Preocupações (Separation of Concerns - SoC)

- Cada módulo na pasta `modules/` deve possuir **uma única responsabilidade**:
  - `00_repos.sh`: Gerenciamento exclusivo de repositórios (RPM Fusion, COPRs, Flathub, Terra e DankLinux).
  - `01_system_hardware.sh`: Hardware base, áudio (PipeWire), Bluetooth e energia (Tuned).
  - `02_gpu_drivers.sh`: Aceleração de vídeo e drivers gráficos (Mesa ou NVIDIA).
  - `03_desktop_apps.sh`: Pacotes de usuário, fontes, terminal, codecs, Brave e Flatpaks.
  - `04_display_stack.sh`: Display managers (Greetd ou SDDM) e integração PAM Keyring.
  - `05_compositor.sh`: Roteador de compositores Wayland (Niri ou Umbriel).
  - `06_desktop_interface.sh`: Roteador de interfaces gráficas (iNiR, Noctalia ou DankLinux).
  - `07_post_install.sh`: Validação final, autostart, layout de teclado ABNT2 e habilitação de serviços.
- É terminantemente proibido instalar aplicativos de usuário (como navegadores ou players) dentro de módulos de hardware ou repositórios.

### 1.2 Infraestrutura como Código (IaC) e Organização Semântica de `config/`

- **Regra de Ouro Arquitetural:** *Código procedural em scripts `.sh` gerencia exclusivamente fluxo, controle e lógica; dados, pacotes, dotfiles e modelos de configuração pertencem estritamente à pasta `config/`.*
- **Exceções Justificadas e Únicas à Regra de Ouro:** bootstrap de repositórios (RPMs de release do RPM Fusion, `dnf-plugins-core`, `flatpak`, habilitação de COPRs) e escolha do microcódigo de CPU (`intel-microcode`/`amd-ucode-firmware`) podem aparecer inline nos módulos, pois *antecedem* a existência dos manifestos ou são selecionados condicionalmente pela arquitetura detectada em tempo de execução — escapam ao modelo de dados estático.
- **Divisão Tripla da Pasta `config/`:**
  1. `config/packages/`: Manifestos declarativos `.conf` para gerenciar dependências do sistema e aplicações (DNF e Flatpak).
  2. `config/desktop/`: Configurações declarativas de interface e dotfiles do usuário aplicadas sob `~/.config/` (ex: `niri/config.kdl`, `umbriel/config.toml`).
  3. `config/system/`: Modelos e arquivos de configuração administrativa aplicados sob `/etc/` (ex: `greetd.toml.template`, `pam_greetd.template`, `pam_sddm.template`).
- **Prevenção de Inchaço do Sistema (Anti-Bloatware):** A segregação por arquivo `.conf` especializado dentro de `config/packages/` impede que dependências pesadas de uma shell ou compositor específico (como o runtime Quickshell do iNiR ou o repositório Terra do Noctalia) poluam a base do sistema de usuários que escolheram outros ambientes.
- **Racional Técnico e Benefícios de IaC:**
  1. *Auditabilidade e Transparência Total:* Administradores, usuários e ferramentas de segurança podem auditar integralmente as dependências de cada camada sem precisar parsear lógica procedural ou expressões regulares em scripts bash.
  2. *Manutenibilidade e Desacoplamento:* Atualizar, adicionar ou remover um pacote ou dotfile não altera o código executável, reduzindo a zero o risco de efeitos colaterais ou regressões em tempo de execução.
  3. *Reutilização e Idempotência:* A instalação é orquestrada pela função utilitária padronizada `install_packages_from_conf`, garantindo que comentários, linhas em branco e parâmetros de contenção (ex: `--exclude=alacritty` ou `--allowerasing`) sejam tratados de forma consistente e segura em qualquer etapa do provisionamento.
- **Formato dos Arquivos Declarativos `.conf`:** Um pacote por linha, com suporte nativo a comentários prefixados com `#` e linhas em branco.
- **Eliminação de `templates/` da Raiz:** Toda e qualquer configuração declarativa de dotfiles e de sistema reside exclusivamente em `config/desktop/` e `config/system/`, eliminando pastas de templates dispersas na raiz do projeto.

### 1.3 A Função Central `install_packages_from_conf`

Localizada em `lib/utils.sh`, a função padroniza o consumo de qualquer arquivo de manifesto `.conf`:

```bash
install_packages_from_conf() {
    local conf_file="$1"
    local extra_args="${2:-}"

    if [[ ! -f "$conf_file" ]]; then
        log_error "Manifesto declarativo não encontrado: ${conf_file}"
        return 1
    fi

    local pkgs=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        pkgs+=("$line")
    done < "$conf_file"

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Instalando pacotes declarados em $(basename "$conf_file")..."
        # shellcheck disable=SC2086
        sudo dnf install -y ${extra_args} "${pkgs[@]}"
    fi
}
```

- **Características:**
  - **Manifesto ausente é erro (não falha silenciosa):** um caminho digitado incorretamente registra `log_error` e retorna `1`, impedindo que uma camada inteira deixe de ser instalada sem aviso — preservando a auditabilidade IaC.
  - Ignora comentários inline ou linhas comentadas com `#`.
  - Ignora espaços e linhas vazias de forma defensiva.
  - Suporta argumentos adicionais do DNF (ex: `--exclude=alacritty`, `--allowerasing`).
  - Executa a chamada DNF em lote com lista de argumentos (`"${pkgs[@]}"`), acelerando drasticamente a resolução de dependências se comparado a chamadas individuais.

### 1.4 Padrão Estratégia (Strategy Pattern)

- Novos compositores devem ser adicionados como submódulos isolados em `modules/compositors/<nome>.sh`.
- Novas interfaces gráficas devem ser adicionadas como submódulos isolados em `modules/interfaces/<nome>.sh`.
- O orquestrador central apenas despacha a execução com base nas escolhas do usuário via `case "${SELECTED_INTERFACE}"`.

---

## 2. Regras Estritas de Programação Shell Defensiva

Todo script criado ou modificado deve seguir as seguintes regras:

### 2.1 Bash Strict Mode Obrigatório

O topo de todo arquivo `.sh` deve conter:

```bash
set -euo pipefail
```

- Nunca desative o `set -e` globalmente. Se um comando puder falhar de forma esperada, trate-o localmente com `comando || true`.

### 2.2 Execução sem Root Direto (Menor Privilégio)

- O instalador **nunca** deve ser executado como `sudo ./install.sh`.
- As variáveis `${REAL_USER}` e `${REAL_HOME}` devem ser sempre preservadas.
- Comandos que modificam configurações de usuário devem ser disparados via:
  ```bash
  sudo -u "${REAL_USER}" comando
  ```
- Ao final de qualquer operação na Home, garanta as permissões corretas com a função auxiliar:
  ```bash
  ensure_user_ownership "${REAL_HOME}/.config"
  ensure_user_ownership "${REAL_HOME}/.local"
  ```

### 2.3 Idempotência Rigorosa

- Toda operação deve poder ser reexecutada sem causar efeitos colaterais.
- Nunca anexe linhas cegas em arquivos existentes usando apenas `>>`. Verifique antes com:
  ```bash
  if ! grep -qF "configuracao_desejada" caminho/do/arquivo; then
      echo "configuracao_desejada" >> caminho/do/arquivo
  fi
  ```

### 2.4 Isolamento de Armazenamento (/tmp vs Home)

- No Fedora, a partição `/tmp` é montada em memória RAM (`tmpfs`), sujeita a esgotamento de espaço em máquinas virtuais.
- Downloads grandes, clonagens de repositórios ou compilações devem ser feitos na Home do usuário (`${REAL_HOME}`) e limpos após o uso.

### 2.5 Validação de Entrada Interativa

- Nenhum prompt de menu deve interpretar silenciosamente uma entrada inválida ou cair em um padrão implícito por omissão.
- Toda leitura interativa usa os helpers de `lib/ui.sh`:
  ```bash
  ui_ask_choice "  Escolha uma opção: " "1" "1|2|3" shell_choice
  ui_ask_yn  "  Deseja instalar drivers NVIDIA? " "n" install_nvidia
  ```
- Esses helpers rejeitam e reperguntam valores fora do conjunto aceito (loop de validação), assumindo o padrão somente quando o usuário pressiona Enter.

### 2.6 Cadeia de Suprimentos (Supply Chain) de Binários Externos

- Ao provisionar binários baixados da internet (ex: runtime Deno), o instalador deve:
  1. Detectar a arquitetura do alvo (`uname -m`) em vez de assumir `x86_64`.
  2. Baixar e **verificar o checksum SHA-256** publicado na release oficial antes de instalar.
  3. Abortar com erro explícito (`exit 1`) se a verificação falhar ou a arquitetura não for suportada.
- Pipelines `curl | sh` de terceiros são circunscritos ao usuário real (`sudo -u "${REAL_USER}"`) e sempre seguidos de reparo defensivo das configurações de sistema que possam sobrescrever.

---

## 3. Diretrizes de Autenticação, PAM e Segurança

1. **Permissões de Arquivos PAM:** Qualquer arquivo em `/etc/pam.d/` deve possuir estritamente posse `root:root` e permissão `644`.
2. **Desbloqueio de Cofre de Senhas:** Todas as sessões gráficas (SDDM ou Greetd) devem implementar integração nativa com `pam_gnome_keyring.so` para evitar pop-ups de desbloqueio de senhas em navegadores.
3. **Encapsulamento de Instaladores Externos:** Se um instalador terceiro (como `dankinstall` ou scripts externos) sobrescrever arquivos de sistema, o submódulo correspondente tem a obrigação de restaurar os templates de segurança antes de concluir sua execução (como efetuado em `modules/interfaces/danklinux.sh`).
4. **Endurecimento do Drop-in Temporário de Sudoers:** A regra NOPASSWD temporária em `/etc/sudoers.d/` deve ser montada em `mktemp`, **validada com `sudo visudo -cf`** antes de qualquer instalação (sintaxe inválida aborta sem tocar `/etc/sudoers`), instalada com `sudo install -m 0440 -o root -g root` e removida por `trap` nos sinais `EXIT HUP INT TERM`. O instalador também remove drop-ins órfãos de execuções anteriores interrompidas (`kill -9`) para não deixar resquícios administrativos persistentes.
5. **Log Fora de Diretórios Compartilhados:** O log de instalação reside em `${XDG_STATE_HOME:-~/.local/state}/fedora-multi-shell/install.log` (nunca em `/tmp` previsível), e o `log_init` recusa um alvo que já exista como link simbólico, mitigando ataques de symlink.
6. **Proibição de `eval` sobre Dados de Usuário:** A resolução de `$HOME` e do usuário real usa `getent passwd` e a cadeia `${SUDO_USER:-${USER:-$(id -un)}}` — jamais `eval echo ~$user`, que permitiria injeção de código via nome de usuário controlável.


---

## 4. Como Adicionar uma Nova Interface Gráfica ao Projeto

Para estender o projeto com uma nova interface:

1. Crie o arquivo declarativo de dependências em `config/packages/<nome>.conf`.
2. Adicione a opção no menu interativo em `install.sh`.
3. Adicione os repositórios necessários em `modules/00_repos.sh`.
4. Crie o submódulo de instalação em `modules/interfaces/<nome>.sh` consumindo o arquivo `.conf` via `install_packages_from_conf`.
5. Adicione o caso correspondente no roteador `modules/06_desktop_interface.sh`.
6. Se a interface exigir autostart ou atalhos específicos, adicione o tratamento no `modules/07_post_install.sh`.
7. Atualize a tabela de opções no `README.md`, no catálogo de pacotes e na documentação técnica.
