# Game Design — Deliver Rush

Documento de visão geral. Os números vivem nos documentos de sistema e nos configs.

---

## 1. Resumo

| Campo | Valor |
| --- | --- |
| **Título** | Deliver Rush |
| **Lugar no Studio** | `Corrida de Entrega` |
| **Plataforma** | Roblox — PC, mobile e console (há mapeamento de controle) |
| **Gênero** | Entrega / corrida urbana com progressão |
| **Modos** | Livre e Sobrevivência |

---

## 2. Os dois modos

> O jogo tem dois modos no código, mas **só um está no ar**.

### 2.1 Sobrevivência — ativo

É o que o jogador joga. Partida curta e intensa: pedidos em sequência, aceitos automaticamente, contra um relógio único.

- Moto fixa no nível 3, só o Centro
- O relógio começa com 60 s, teto de 120 s
- Cada entrega soma tempo, mas o bônus encolhe de 30 s até 15 s
- A cada 5 entregas, escolha de 1 entre 3 habilidades
- Trânsito, pedestres e perigos escalam a cada entrega
- Sem dinheiro, sem Oficina, sem bairros
- O que se acumula entre partidas: o **recorde de entregas**, salvo e exibido no ranking da praça

→ [Modo Sobrevivência](sistemas/sobrevivencia.md)

### 2.2 História — desativado

O loop de dinheiro, Oficina e bairros. Roda apenas quando o atributo `GameMode` do jogador é `"Story"`.

- Um pedido ativo por vez (`MaxActiveOrders = 1`)
- Cinco bairros, desbloqueio sequencial
- Seis níveis de moto
- Sem relógio global — cada pedido tem prazo próprio

O código está completo e os configs estão balanceados, mas nada disso chega ao jogador hoje.

→ [Economia e Progressão](sistemas/economia-e-progressao.md)

---

## 3. Loop do modo livre

```
Aceitar pedido
      ↓
Ir ao restaurante  ──── perigos, trânsito, clima
      ↓
Pegar a comida
      ↓
Ir até o cliente   ──── perigos, trânsito, clima
      ↓
Entregar dentro do raio de 16 studs
      ↓
Pagamento = base + distância, × velocidade × gorjeta × área × combo
      ↓
Investir: nível de moto ou bairro novo
      └──────────────► novo pedido em 2 s
```

---

## 4. O que cria tensão

### 4.1 Velocidade paga, literalmente

O multiplicador de velocidade vai de 2,5× (metade do tempo ideal) a 0,4× (dobro do tempo). E o prazo é calculado sobre a velocidade do **nível 0**, não sobre a moto atual — então moto melhor não ganha prazo mais folgado, ganha pagamento maior. O incentivo a correr é estrutural.

### 4.2 Correr é difícil de propósito

`MinTurnFactor = 0.35` — na velocidade máxima a moto vira a pouco mais de um terço. Acelerar reduz a capacidade de desviar exatamente quando há mais o que desviar.

### 4.3 O turbo custa controle

Carregar o turbo exige 1,2 s de grau, e durante o grau a moto vira pela metade. É pedir ao jogador que abra mão de controle para ganhar velocidade.

→ [Moto e Manobras](sistemas/moto-e-manobras.md)

### 4.4 Erro custa dinheiro

Atropelar pedestre: 50. Pneu furado: 20. Radar: 15. Carro: 10. Fora da pista: taxa crescente a cada 1,6 s. O erro não tira multiplicador — tira saldo.

→ [Perigos e Taxas](sistemas/perigos-e-taxas.md)

---

## 5. Progressão

### 5.1 Dinheiro — modo livre

| Investimento | Custo total | Retorno |
| --- | --- | --- |
| Moto nível 0 → 5 | 35.000 | 40 → 110 studs/s (80 → 220 km/h) |
| Todos os bairros | 81.000 | Multiplicador de 1,0× a 3,5× |

Os dois competem pelo mesmo dinheiro. O desbloqueio de bairro é mais caro mas escala melhor, já que o `PayMultiplier` se aplica a todo pagamento.

→ [Economia e Progressão](sistemas/economia-e-progressao.md)

### 5.2 Estrelas — Sobrevivência

Três missões por dia rendem de 3 a 6 estrelas. As cinco motos da Garagem custam 115 estrelas no total, o que dá cerca de 26 dias de jogo diário.

As estrelas compram apenas aparência. Nenhuma moto da Garagem muda desempenho.

→ [Missões e Garagem](sistemas/missoes-e-garagem.md)

### 5.3 As duas economias não se tocam

| Circuito | Moeda | Fonte | Gasto |
| --- | --- | --- | --- |
| Progressão | Dinheiro | Entregas no modo livre | Nível de moto, bairros |
| Cosmético | Estrelas | Missões diárias da Sobrevivência | Motos da Garagem |

É uma separação limpa: o modo livre é onde o jogador fica mais forte, a Sobrevivência é onde ele fica mais bonito. Mas significa que quem só joga um dos modos nunca vê metade do conteúdo de recompensa.

---

## 6. Sistemas implementados

| Sistema | Estado da documentação |
| --- | --- |
| Pedidos e pagamento | Documentado |
| Bairros e níveis de moto | Documentado |
| Pilotagem, grau, turbo | Documentado |
| Sobrevivência e habilidades | Documentado |
| Perigos, taxas, clima, dia/noite | Documentado |
| Anti-exploit | Documentado |
| Missões e Garagem | Documentado |
| Rotas e rede de ruas | Documentado |
| **Ranking** (`LeaderboardManager`, `LiveBoard`) | ❌ Não documentado |
| **Analytics** | ❌ Não documentado |
| **`RoadMap`** (separado do `RoadGraph`) | ❌ Não documentado |

---

## 7. Pendências

Faltam dois configs para fechar: o que o `LeaderboardManager` rankeia e o que o `Analytics` registra.

E quatro perguntas de design que os configs não respondem:

- As habilidades persistem entre partidas de Sobrevivência? (O atributo `Abilities` é salvo no perfil, o que sugere que sim — mas isso mudaria bastante o modo)
- A Sobrevivência dá dinheiro, ou só estrelas?
- As bolas de demolição aparecem no modo livre ou só na Sobrevivência?
- O que o `RoadMap` faz que o `RoadGraph` não faz?

---

## 8. Histórico

| Versão | Data | Mudanças |
| --- | --- | --- |
| 0.2 | 2026-11-11 | Reescrito a partir dos configs reais do jogo |
| 0.1 | 2026-11-11 | Rascunho inicial, baseado em descrição verbal |
