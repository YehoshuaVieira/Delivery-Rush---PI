# Guia de Contribuição

Como a equipe trabalha neste repositório.

---

## 1. Antes de começar

1. Leia o [Game Design Document](docs/game-design.md) — mudanças que contrariam os pilares de design precisam ser discutidas antes de virar código.
2. Configure o ambiente seguindo [Como rodar o projeto](README.md#como-rodar-o-projeto).
3. Confirme que `rojo serve` conecta e que o jogo roda no Studio antes de escrever qualquer coisa.

---

## 2. Fluxo de trabalho

### 2.1 Branches

| Branch | Função |
| --- | --- |
| `main` | Versão estável e publicável. Nunca receber commit direto. |
| `dev` | Integração do trabalho em andamento. Base de todas as branches de feature. |
| `feat/<nome>` | Uma funcionalidade nova |
| `fix/<nome>` | Correção de bug |
| `docs/<nome>` | Alteração só em documentação |
| `balance/<nome>` | Ajuste de valores sem mudança de lógica |

```bash
git checkout dev
git pull
git checkout -b feat/sistema-de-cartas
```

### 2.2 Commits

Padrão [Conventional Commits](https://www.conventionalcommits.org/):

```
<tipo>(<escopo>): <descrição no imperativo>
```

| Tipo | Uso |
| --- | --- |
| `feat` | Funcionalidade nova |
| `fix` | Correção de bug |
| `docs` | Documentação |
| `balance` | Ajuste de valores de jogo |
| `refactor` | Mudança de código sem alterar comportamento |
| `perf` | Melhoria de performance |
| `chore` | Build, ferramentas, configuração |

Exemplos:

```
feat(cards): adicionar sorteio por raridade com pity counter
fix(delivery): validar distância no servidor antes de pagar
balance(economy): reduzir custo do bairro 3 de 40k para 25k
docs(traps): documentar regras de legibilidade
```

### 2.3 Pull requests

Toda alteração entra por PR, mesmo as pequenas. Nenhum push direto em `dev` ou `main`.

**Requisitos para abrir:**

- [ ] O código roda no Studio sem erros no output
- [ ] `--!strict` presente nos módulos novos, sem erros de tipo
- [ ] StyLua e Selene passam sem avisos
- [ ] A documentação correspondente foi atualizada
- [ ] A descrição explica **o que** mudou e **por quê**

**Requisitos para aprovar:**

- Ao menos 1 revisão de outro membro
- Se a mudança afeta balanceamento, alguém precisa ter testado em jogo

---

## 3. Padrões de código

Convenções completas em [Arquitetura Técnica](docs/arquitetura.md#7-convenções-de-código). O essencial:

- `--!strict` no topo de todo módulo novo
- Serviços do Roblox no topo, depois módulos compartilhados
- Nenhum valor de balanceamento hardcoded fora de `src/shared/Config/` ou `src/shared/Data/`
- Nenhum `RemoteEvent` criado fora de `src/shared/Remotes.luau`
- Nenhum remote que aceite valores de progresso vindos do cliente

### 3.1 Formatação

```bash
stylua src/      # formatar
selene src/      # lintar
```

Rode os dois antes de abrir o PR.

---

## 4. Arquivos `.rbxl`

> ⚠️ **Arquivos `.rbxl` não entram no Git.**

O código-fonte vive em `src/` e é sincronizado pelo Rojo. O arquivo do lugar contém o mapa e os assets, e é compartilhado pela equipe via [definir: Roblox Team Create ou armazenamento externo].

Motivo: `.rbxl` é binário. Git não consegue fazer merge dele, e dois membros editando o mapa ao mesmo tempo resultam em perda de trabalho garantida.

**Para o mapa, use Team Create.** Para o código, use Git.

---

## 5. Alterações de balanceamento

Mudar um número é fácil. Mudar o número certo não é.

Antes de alterar qualquer valor em `Config/` ou `Data/`:

1. Diga qual problema o número atual causa, com base em teste real e não em suposição
2. Verifique o checklist do documento do sistema correspondente
3. Anote o valor antigo na descrição do PR, para permitir reversão
4. Mudanças grandes devem ser testadas por mais de uma pessoa

Commits de balanceamento usam o tipo `balance` justamente para serem fáceis de rastrear e reverter.

---

## 6. Reportando bugs

Abra uma issue com:

```markdown
**O que aconteceu**
<descrição>

**O que deveria acontecer**
<descrição>

**Como reproduzir**
1.
2.
3.

**Onde**
Studio / Jogo publicado / Ambos
Plataforma: PC / Mobile / Console

**Output**
<erros do console, se houver>
```

Bugs de exploit (jogador ganhando dinheiro indevido, duplicação, teletransporte) têm prioridade máxima e devem ser marcados com a label `security`.

---

## 7. Documentação

A documentação faz parte da entrega, não é um extra. Um PR que adiciona uma carta sem adicioná-la ao [catálogo](docs/sistemas/cartas.md) está incompleto.

| Se você mudou... | Atualize... |
| --- | --- |
| Valores de economia | `docs/sistemas/economia-e-progressao.md` |
| Cartas | `docs/sistemas/cartas.md` |
| Armadilhas ou multiplicador | `docs/sistemas/armadilhas-e-multiplicador.md` |
| Estrutura de código ou remotes | `docs/arquitetura.md` |
| Escopo ou pilares de design | `docs/game-design.md` |

---

## 8. Dúvidas

[Definir canal — Discord, WhatsApp, issues do GitHub]
