# Moto e Manobras

Pilotagem, grau, turbo e salto. Valores de `GameConfig.Moto` e `GameConfig.Maneuver`.

---

## 1. Direção

| Parâmetro | Valor | Função |
| --- | --- | --- |
| `TurnSpeed` | 140 graus/s | Velocidade de esterço |
| `FullTurnSpeed` | 15 | Velocidade (studs/s) abaixo da qual a curva é total |
| `MinTurnFactor` | 0,35 | Na velocidade máxima, a moto vira só 35% do normal |
| `LeanAngle` | 12° | Inclinação visual na curva |

A moto vira bem devagar e bem pouco em alta velocidade. É o que impede que a estratégia ótima seja segurar o acelerador o tempo todo.

---

## 2. Frenagem

| Parâmetro | Valor |
| --- | --- |
| `BrakeDeceleration` | 130 studs/s² |
| `CoastDeceleration` | 22 studs/s² |
| `ReverseSpeedFactor` | 0,35 |

Soltar o acelerador desacelera 6× mais devagar do que frear. A ré anda a 35% da velocidade.

---

## 3. Impacto e pneu

| Parâmetro | Valor |
| --- | --- |
| `BumpMinSpeed` | 15 studs/s — abaixo disso não há solavanco |
| `BumpBounce` | 0,25 |
| `FlatTireTime` | 3 s parado |
| `FlatTireImmunity` | 2 s de imunidade depois |

Pneu furado é o perigo mais caro em tempo parado. A carta **Pneus Reforçados** anula completamente.

---

## 4. Grau e turbo

O grau (wheelie) não é enfeite — é como se carrega o turbo.

| Parâmetro | Valor |
| --- | --- |
| `GrauMinSpeed` | 15 studs/s para iniciar |
| `GrauAngle` | 24° |
| `GrauChargeTime` | 1,2 s de grau para encher o turbo |
| `GrauMaxTime` | 3 s de grau no máximo |
| `GrauTurnFactor` | 0,5 — vira pela metade durante o grau |
| `MinChargeToBoost` | 0,3 — carga mínima para o turbo valer |

| Turbo | Valor |
| --- | --- |
| `BoostMultiplier` | 1,3× de velocidade |
| `BoostAccelMultiplier` | 2× de aceleração |
| `BoostDuration` | 2 s |
| `Cooldown` | 0,8 s |

### 4.1 O trade-off

Durante o grau a moto vira pela metade (`GrauTurnFactor = 0.5`), e a direção já é ruim em alta velocidade (`MinTurnFactor = 0.35`). Combinados, fazer grau em velocidade alta deixa a moto quase sem capacidade de desviar — exatamente enquanto o jogador precisa de 1,2 s parado na manobra.

Essa é a mecânica de risco mais bem desenhada do jogo: o turbo custa controle no momento em que ele é mais necessário.

### 4.2 Limite do anti-exploit

O comentário do config registra que o `AntiExploitValidation` tolera até **+35%** de velocidade. O turbo dá +30%. A margem é de 5 pontos — qualquer aumento no `BoostMultiplier` precisa de ajuste correspondente no `SpeedTolerance`, senão jogador legítimo é marcado como exploiter.

---

## 5. Salto

| Parâmetro | Valor |
| --- | --- |
| `JumpMinAirTime` | 0,3 s |
| `AirGravityScale` | 0,4 — gravidade reduzida no ar |
| `JumpChargeBonus` | 0,5 |
| `FailSpeedFactor` | 0,5 — pouso mal feito corta metade da velocidade |

A carta **Salto Extremo** (`Impulse = 46`) é o salto como habilidade ativa.

---

## 6. Fora de pista

`GameConfig.OffRoad` — sair do asfalto é punido de duas formas ao mesmo tempo.

| Parâmetro | Valor |
| --- | --- |
| `SpeedFactor` | 0,5 — metade da velocidade |
| `Fee` | 3 na primeira cobrança |
| `FeeIncrease` | +1 por cobrança (3, 4, 5, 6...) |
| `Interval` | 1,6 s fora da rua por cobrança |
| `ResetAfter` | 3 s seguidos no asfalto para zerar |

A multa é **crescente e não para de subir**. Dez segundos de calçada custam cerca de seis cobranças somando 33, e continua escalando. Cortar caminho pela grama precisa ser muito curto para compensar.

---

## 7. Câmera

| Parâmetro | Valor |
| --- | --- |
| `Distance` | 23 |
| `Height` | 9 |
| `LookAhead` | 18 |
| `YawSmoothing` | 8 |
| `BaseFOV` | 70 |
| `MaxFOV` | 100 |

O FOV abre de 70 para 100 conforme a velocidade — sensação de velocidade sem mexer na velocidade real.

---

## 8. Mundo

| Parâmetro | Valor |
| --- | --- |
| `World.Limit` | 3.450 studs em X/Z — além disso o reset manda para o spawn |
| `SpeedDisplayFactor` | 2 — converte studs/s em km/h no HUD |
