# Perigos e Taxas

Obstáculos, multas e clima. Valores de `GameConfig.Fees`, `GameConfig.World.Weather` e `GameConfig.Survival`.

Gerenciados por `IncidentManager` (servidor) e `WorldFX` / `WeatherFX` (cliente).

---

## 1. O modelo de punição

O jogo **não** usa perda de multiplicador como punição principal. Usa duas outras:

| Punição | Como funciona |
| --- | --- |
| **Taxa em dinheiro** | Bater, atropelar ou sair da pista cobra do saldo |
| **Tempo perdido** | Colisão, pneu furado e derrapagem custam segundos |

No modo livre o tempo perdido reduz o multiplicador de velocidade do pagamento. Na Sobrevivência, sai direto do relógio da partida.

---

## 2. Taxas

| Evento | Taxa | Cooldown |
| --- | --- | --- |
| Atropelar pedestre | **50** | 1,5 s |
| Pneu furado (conserto) | 20 | — |
| Radar | 15 | 3 s |
| Bater em carro | 10 | 2,5 s |
| Fora da pista | 3, +1 por cobrança | a cada 1,6 s |

`CarCrashMinSpeed = 12` — batida abaixo de 12 studs/s não cobra.

### 2.1 Leitura

Atropelar pedestre custa **5× mais** que bater em carro. O jogo pune agressão a pessoa muito mais do que dano material, o que é uma escolha de design defensável e vale manter explícita.

O cooldown de 1,5 s do pedestre é o mais curto da tabela. Entrar na multidão a 150 km/h pode cobrar várias vezes seguidas — 50, 100, 150 em poucos segundos. É a forma mais rápida de perder dinheiro no jogo.

---

## 3. Perigos de chão

Aparecem no caminho dos pedidos, principalmente na Sobrevivência.

| Perigo | Efeito | Carta que anula |
| --- | --- | --- |
| **Pregos** | Fura o pneu — 3 s parado | Pneus Reforçados |
| **Buraco** | Freia e arremessa | Pneus Reforçados |
| **Óleo** | Derrapagem | Tração Total |
| **Água** | Derrapagem | Tração Total |
| **Lama** | –55% de velocidade | Tração Total (reduz para –15%) |

Escudo (**Campo de Proteção**) bloqueia o próximo impacto de qualquer um deles, uma vez a cada 45 s. **Modo Fantasma** atravessa todos por 3 s.

---

## 4. Perigos móveis

| Perigo | Origem |
| --- | --- |
| **Carros** | Trânsito ambiente; na Sobrevivência escala até 3× o volume e 1,4× a velocidade |
| **Pedestres** | Nas calçadas e atravessando a rua |
| **Bolas de demolição** | Citadas em `WorldFX` e na carta Câmera Lenta — mecânica ainda não documentada |
| **Blitz** | Evento de Sobrevivência: limite de 60 km/h, 3 s de multa |
| **Engarrafamento** | Evento de Sobrevivência: 25 s de carros parados |

Detalhes da escalada em [Modo Sobrevivência](sobrevivencia.md#4-escalada-de-dificuldade).

---

## 5. Clima

`GameConfig.World.Weather` — o clima é **do servidor**, todos os jogadores veem o mesmo.

| Parâmetro | Valor |
| --- | --- |
| `Enabled` | `true` |
| `SunMinutes` | 4 a 7 minutos de sol |
| `RainChance` | 45% ao fim de cada período de sol |
| `RainMinutes` | 2 a 4 minutos de chuva |
| `RainTurn` | 0,86 — a moto vira 14% menos |
| `RainBrake` | 0,78 — freia 22% menos |

A chuva piora as duas coisas que já são difíceis na moto: curva e frenagem. **Tração Total** anula o efeito.

### 5.1 Ciclo dia/noite

`GameConfig.World.DayNight`:

| Parâmetro | Valor |
| --- | --- |
| `Enabled` | `true` |
| `DayMinutes` | 10 |
| `NightMinutes` | 3 |
| `StartHour` | 9 |

Ciclo total de 13 minutos, com a noite ocupando menos de um quarto.

---

## 6. Anti-exploit

`GameConfig.AntiExploit` — o servidor mede a velocidade do jogador em janelas.

| Parâmetro | Valor |
| --- | --- |
| `SampleInterval` | 0,5 s |
| `Window` | 2,5 s de janela (tolera lag) |
| `MinWindow` | 1,5 s |
| `SpeedTolerance` | 1,35 |
| `SpeedMargin` | 10 |
| `MinTimeSpeedFactor` | 1,45 |

A tolerância de 1,35 precisa acomodar o turbo legítimo de 1,30. Ver [Moto e Manobras](moto-e-manobras.md#42-limite-do-anti-exploit).

### 6.1 Limites de requisição

`GameConfig.RateLimits`, em segundos entre chamadas:

| Ação | Limite |
| --- | --- |
| `ResetMoto` | 3 s |
| `Survival` | 1 s |
| `GetState` | 0,5 s |
| `Shop` | 0,4 s |
| `OrderAction` | 0,4 s |

---

## 7. Pontos em aberto

- [ ] Como funcionam as bolas de demolição? Onde aparecem, dano, frequência.
- [ ] O radar fica em posição fixa no mapa ou é evento?
- [ ] A taxa de fora de pista tem teto, ou sobe indefinidamente?
