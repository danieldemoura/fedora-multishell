# 🏛️ Diretrizes de Arquitetura, Engenharia e Boas Práticas

Este documento estabelece as regras de design, engenharia de software e padrões de programação defensiva adotados no projeto **Fedora Multi-Shell**.

Todas as futuras contribuições humanas e comandos executados por **Agentes de Inteligência Artificial** devem seguir estritamente as diretrizes abaixo.

---

## 1. Princípios de Arquitetura de Software

### 1.1 Separação de Preocupações (Separation of Concerns - SoC)

- Cada módulo na pasta `modules/` deve possuir **uma única responsabilidade**:
  - `00_repos.sh`: Gerenciamento exclusivo de repositórios (RPM Fusion, COPRs, Flathub).
  - `01_system_hardware.sh`: Hardware base, áudio (PipeWire), Bluetooth e energia.
  - `02_gpu_drivers.sh`: Aceleração de vídeo e drivers gráficos.
  - `03_desktop_apps.sh`: Pacotes de usuário, fontes, terminal e codecs.
  - `04_display_stack.sh`: Display managers e integração PAM.
  - `05_compositor.sh`: Roteador de compositores Wayland.
  - `06_desktop_interface.sh`: Roteador de interfaces gráficas.
  - `07_post_install.sh`: Validação final, autostart e habilitação de serviços.
- É terminantemente proibido instalar aplicativos de usuário (como navegadores ou players) dentro de módulos de hardware ou repositórios.

### 1.2 Configuração Declarativa vs. Imperativa

- **Não embutir listas de pacotes dentro dos scripts `.sh`:** Todos os pacotes devem ser listados em arquivos `.conf` dentro da pasta `config/` (um pacote por linha, com suporte a comentários `#`).
- **Uso de Templates:** Arquivos de configuração complexos (PAM, Greetd, Niri, Umbriel) devem ser mantidos como modelos limpos na pasta `templates/`, e não gerados dinamicamente via blocos extensos de `cat <<EOF` dentro do código.

### 1.3 Padrão Estratégia (Strategy Pattern)

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

- O instalador **nunca** deve ser executado como `sudo ./setup.sh`.
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

---

## 3. Diretrizes de Autenticação, PAM e Segurança

1. **Permissões de Arquivos PAM:** Qualquer arquivo em `/etc/pam.d/` deve possuir estritamente posse `root:root` e permissão `644`.
2. **Desbloqueio de Cofre de Senhas:** Todas as sessões gráficas (SDDM ou Greetd) devem implementar integração nativa com `pam_gnome_keyring.so` para evitar pop-ups de desbloqueio de senhas em navegadores.
3. **Encapsulamento de Instaladores Externos:** Se um instalador terceiro (como `dankinstall` ou scripts externos) sobrescrever arquivos de sistema, o submódulo correspondente tem a obrigação de restaurar os templates de segurança antes de concluir sua execução.

---

## 4. Como Adicionar uma Nova Interface Gráfica ao Projeto

Para estender o projeto com uma nova interface:

1. Adicione a opção no menu interativo em `setup.sh`.
2. Adicione os repositórios necessários em `modules/00_repos.sh`.
3. Crie o submódulo de instalação em `modules/interfaces/<nome>.sh`.
4. Adicione o caso correspondente no roteador `modules/06_desktop_interface.sh`.
5. Se a interface exigir autostart ou atalhos específicos, adicione o tratamento no `modules/07_post_install.sh`.
6. Atualize a tabela de opções no `README.md` e na documentação técnica.
