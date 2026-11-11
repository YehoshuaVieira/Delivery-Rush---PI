# Economia e Progressão

> ⚠️ **Modo História — desativado.** Tudo neste documento só roda quando o atributo `GameMode` do jogador é `"Story"`, o que não acontece no jogo publicado. O código existe e funciona; o jogador não chega nele. Leia como referência do que está implementado, não do que está no ar.

Valores extraídos de `AreaConfig`, `UpgradeConfig` e `GameConfig`.

---

## 1. Bairros

Cinco áreas. O desbloqueio é **sequencial** — `AreaConfig.RequireSequentialUnlock = true`, ou seja, não dá para pular direto para o Centro Financeiro.

| Id | Nome | Custo | Multiplicador de pagamento | Pasta no Workspace |
| --- | --- | --- | --- | --- |
| 1 | Centro | Grátis | 1,0× | `Area1_Centro` |
| 2 | Bairro Residencial | 3.000 | 1,4× | `Area2_Residencial` |
| 3 | Zona Comercial | 8.000 | 1,9× | `Area3_Comercial` |
| 4 | Bairro Nobre | 20.000 | 2,6× | `Area4_Nobre` |
| 5 | Centro Financeiro | 50.000 | 3,5× | `Area5_Financeiro` |

**Custo total para desbloquear tudo: 81.000.**

Cada área também define `Color` (cor no mapa e na UI), `Tint` e `Saturation` (tratamento visual aplicado pelo `AreaVisuals`).

### 1.1 Sorteio de pedidos

Os bairros desbloqueados competem pelo pedido seguinte, com peso favorecendo os mais novos:

```
peso = 1 + (id - 1) × NewerAreaWeight        -- NewerAreaWeight = 0.5
```

Na prática, com todos os bairros abertos: Centro peso 1,0 e Centro Financeiro peso 3,0. O jogador que desbloqueou tudo recebe mais pedidos nas áreas caras.

`SameAreaChance = 0.8` — 80% dos pedidos têm coleta e entrega dentro do mesmo bairro.

---

## 2. Níveis de moto

Uma moto só, seis níveis. Não existe troca de veículo.

| Nível | Velocidade (studs/s) | Velocidade (km/h) | Aceleração | Custo |
| --- | --- | --- | --- | --- |
| 0 | 40 | 80 | 30 | Grátis |
| 1 | 50 | 100 | 37 | 500 |
| 2 | 62 | 124 | 45 | 1.500 |
| 3 | 76 | 152 | 54 | 4.000 |
| 4 | 92 | 184 | 64 | 9.000 |
| 5 | 110 | 220 | 76 | 20.000 |

**Custo total para chegar ao nível 5: 35.000.**

O HUD mostra km/h aplicando `GameConfig.Moto.SpeedDisplayFactor = 2` sobre studs/s.

> **Carenagens não são upgrade de desempenho.** O `UpgradeConfig` só controla Speed e Acceleration. Carenagem e skin estão no `CosmeticManager` / `CosmeticConfig`, com a moeda "estrelas" da Garagem — sistema ainda não documentado aqui.

---

## 3. Cálculo do pagamento

A composição exata está em `PaymentCalculator`. Os componentes, vindos do `GameConfig`:

### 3.1 Base

```
base = BasePay + (distância_em_studs × PayPerStud)
```

| Parâmetro | Valor |
| --- | --- |
| `BasePay` | 60 (referência da Área 1) |
| `PayPerStud` | 0,05 |
| `MinDeliveryDistance` | 600 studs |
| `MaxDeliveryDistance` | 1.600 studs |

### 3.2 Multiplicador de velocidade

O pagamento depende de quanto o tempo real se afastou do tempo ideal:

| Tempo real / tempo ideal | Multiplicador |
| --- | --- |
| 0,5 (metade do tempo) | 2,5× |
| 1,0 (no tempo) | 1,0× |
| 2,0 (dobro do tempo) | 0,4× |

Valores entre esses pontos são interpolados. Entregar rápido mais que dobra o pagamento; enrolar corta para menos da metade.

### 3.3 Gorjeta

Fator aleatório entre `TipMin = 0.9` e `TipMax = 1.1`. Ruído de ±10% para que entregas idênticas não paguem sempre o mesmo número.

### 3.4 Combo

| Parâmetro | Valor | Significado |
| --- | --- | --- |
| `MinSpeedMultiplier` | 1,5 | Só conta como combo se a entrega teve multiplicador de velocidade ≥ 1,5 |
| `BonusPerCombo` | 0,1 | +10% por entrega em sequência |
| `MaxBonus` | 0,5 | Teto de +50% |

O combo não é uma sequência de entregas quaisquer — é uma sequência de entregas **rápidas**. Entregar no prazo com folga não alimenta o combo.

### 3.5 Multiplicador de área

O pagamento final é escalado pelo `PayMultiplier` da área do pedido (tabela da seção 1).

### 3.6 Pedidos especiais

`SpecialChance = 0.1` — 10% dos pedidos são especiais:

- `SpecialPayMultiplier = 2` — pagam o dobro
- `SpecialTimeMultiplier = 0.75` — prazo 25% menor

---

## 4. Cálculo do prazo

| Parâmetro | Valor | Função |
| --- | --- | --- |
| `ReferenceSpeed` | 40 studs/s | Velocidade do nível 0, **fixa** |
| `RouteFactor` | 1,35 | As ruas não são linha reta |
| `ExtraTime` | 6 s | Tolerância |

O prazo é calculado sobre a velocidade do nível 0, não sobre a moto atual. Isso é intencional e está comentado no config: **moto melhor entrega mais rápido e ganha mais**. O upgrade de moto se paga via multiplicador de velocidade, não via prazo mais folgado.

---

## 5. Ritmo dos pedidos

| Parâmetro | Valor |
| --- | --- |
| `MaxActiveOrders` | 1 |
| `OfferDelay` | 2 s até a próxima oferta |
| `DeclineCooldown` | 3 s extras após recusar ou cancelar |
| `PointRadius` | 16 studs para coletar ou entregar |
| `RestaurantCandidates` | 3 restaurantes sorteados, usa o mais perto |

---

## 6. Observações de balanceamento

**O gargalo é o bairro, não a moto.** Maximizar a moto custa 35.000; desbloquear todos os bairros custa 81.000. E como o `PayMultiplier` do Centro Financeiro é 3,5×, o retorno de desbloquear bairro supera o de subir nível depois de certo ponto.

**O nível 5 custa mais que os cinco anteriores somados.** 20.000 contra 15.000 — a curva é agressiva no final, o que é padrão em simulador.

**O combo exige velocidade, não só constância.** Com `MinSpeedMultiplier = 1.5`, o jogador precisa entregar em cerca de 70% do tempo ideal ou menos para o combo contar. Vale verificar em playtest se isso é alcançável com moto nível 0 — se não for, o combo é inacessível para jogador novo.

---

## 7. Persistência

Atributos no perfil (`PlayerDataManager`, DataStore `iFoodRoblox_PlayerData_v1`):

| Dado | Formato |
| --- | --- |
| `UnlockedAreas` | String `"1,2,3"` — parseada por `AreaConfig.ParseUnlocked` |
| `Abilities` | String `"shield,jump"` — parseada por `AbilityConfig.Parse` |
| Dinheiro | Número |
| Nível da moto | Número 0–5 |

| Parâmetro | Valor |
| --- | --- |
| `AutosaveInterval` | 120 s |
| `MaxRetries` | 4 |
| `StartingMoney` | 0 |
