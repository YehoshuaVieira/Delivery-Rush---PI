# Habilidades

Sistema de cartas do [modo Sobrevivência](sobrevivencia.md). Valores de `AbilityConfig`.

> As habilidades pertencem à Sobrevivência, não ao modo livre.

---

## 1. Como funciona

A cada **5 entregas** o jogador escolhe **1 entre 3** cartas sorteadas — o modelo de Hades e Vampire Survivors, não o de caixa de recompensa.

| Parâmetro | Valor |
| --- | --- |
| `EveryDeliveries` | 5 |
| `Choices` | 3 |
| `PickTimeout` | 30 s — depois disso a primeira carta é escolhida sozinha |
| `PadPick` | `X`, `Y`, `B` para as cartas 1, 2 e 3 no controle |

A escolha entre três opções é o que faz o sistema funcionar: o jogador constrói uma build de verdade em vez de receber o que o acaso mandou.

---

## 2. Raridades

O peso é a chance relativa de a carta aparecer numa escolha.

| Raridade | Peso | Cor |
| --- | --- | --- |
| Comum | 1,00 | `190, 196, 204` |
| Raro | 0,60 | `77, 163, 255` |
| Épico | 0,35 | `181, 124, 255` |
| Lendário | 0,18 | `255, 176, 32` |

Não há proteção contra azar (pity). Uma partida pode terminar sem nenhuma Lendária.

---

## 3. Tipos

| Tipo | Significado |
| --- | --- |
| **Passiva** | Sempre ativa |
| **Automática** | Dispara sozinha quando uma condição acontece |
| **Ativa** | O jogador aperta a tecla |

---

## 4. As 14 habilidades

### 4.1 Comuns

| Carta | Tipo | Efeito |
| --- | --- | --- |
| **Nitro de Emergência** | Automática | Turbo de 4 s quando o relógio chega a 12 s. Uma vez por pedido |
| **Entregador Magnético** | Passiva | Raio de coleta e entrega 75% maior |
| **Pneus Reforçados** | Passiva | Pregos não furam o pneu; buracos não freiam nem arremessam |
| **Tração Total** | Passiva | Óleo e água não fazem derrapar; lama tira 15% da velocidade em vez de 55% |
| **Para-choque Reforçado** | Passiva | Batidas mantêm 70% da velocidade, sem recuo nem tontura; carros empurram pela metade |

### 4.2 Raras

| Carta | Tipo | Tecla | Efeito |
| --- | --- | --- | --- |
| **Campo de Proteção** | Passiva | — | Escudo bloqueia o próximo impacto de qualquer tipo. Recarrega em 45 s |
| **Modo Fantasma** | Ativa | `F` / `LB` | Atravessa carros, pedestres e perigos do chão por 3 s. Recarga 35 s |
| **Entrega Perfeita** | Passiva | — | A cada 3 entregas seguidas sem bater, a 3ª soma +8 s |
| **Saída Rápida** | Automática | — | Turbo de 2,5 s ao começar um pedido e ao pegar a comida |

### 4.3 Épicas

| Carta | Tipo | Tecla | Efeito |
| --- | --- | --- | --- |
| **Salto Extremo** | Ativa | `Espaço` / `Y` | Salta por cima de carros, pregos, buracos e poças. Recarga 18 s, impulso 46 |
| **Sirene** | Ativa | `Q` / `RB` | Carros e pedestres num raio de 50 studs param por 4 s. Recarga 25 s |
| **Hora Extra** | Passiva | — | Toda entrega soma +3 s |

### 4.4 Lendárias

| Carta | Tipo | Tecla | Efeito |
| --- | --- | --- | --- |
| **Segunda Chance** | Automática | — | Uma vez por partida: ao zerar o relógio, ganha +15 s em vez de perder |
| **Câmera Lenta** | Ativa | `E` / `A` | Trânsito, pedestres e bolas de demolição a 30% da velocidade por 5 s. Recarga 35 s |

---

## 5. Leitura do conjunto

**Cinco das catorze anulam perigos específicos.** Pneus Reforçados (pregos e buracos), Tração Total (óleo, água, lama), Para-choque (batidas), Campo de Proteção (qualquer um, uma vez) e Modo Fantasma (todos, por 3 s). Uma build que junte as três passivas de perigo fica praticamente imune ao chão — vale checar em playtest se isso quebra a curva de dificuldade do modo.

**Três dão tempo direto.** Entrega Perfeita (+8 s por sequência), Hora Extra (+3 s por entrega) e Segunda Chance (+15 s uma vez). Hora Extra é a mais forte a longo prazo: na 16ª entrega em diante, quando o bônus trava em 15 s, +3 s é 20% a mais de relógio por entrega.

**Tração Total tem interação com o clima.** O `GameConfig.World.Weather` diz que a chuva reduz a curva da moto para 0,86 e a frenagem para 0,78, e que Tração Total anula isso. É a única carta com efeito fora do seu próprio escopo.

---

## 6. Dados

```lua
AbilityConfig.List   -- array das 14 cartas
AbilityConfig.ById   -- índice por Id
AbilityConfig.Get(id)
AbilityConfig.Parse(text)  -- "shield,jump" -> { shield = true, jump = true }
```

Ids: `shield`, `nitro`, `magnet`, `ghost`, `perfect`, `jump`, `second`, `tires`, `grip`, `bumper`, `launch`, `overtime`, `siren`, `slowmo`.

O atributo `Abilities` do jogador guarda os ids separados por vírgula.

### 6.1 Ao adicionar uma carta

Cada entrada precisa de `Id`, `Name`, `Rarity`, `Icon`, `Kind`, `Tagline` e `Description`. Campos extras conforme o tipo: `Cooldown`, `Duration`, `Key` e `Pad` para ativas; parâmetros próprios do efeito (`RadiusMultiplier`, `KeepSpeed`, `Bonus`, `Scale`...) para o resto.

A `Description` aparece no card da UI — mantenha no mesmo tom das existentes, explicando o efeito em número concreto e não em adjetivo.
