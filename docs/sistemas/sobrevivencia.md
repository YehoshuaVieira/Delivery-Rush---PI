# Modo Sobrevivência

Modo alternativo ao jogo livre. Pedidos em sequência contra **um relógio único** — quando ele zera, a partida acaba.

Valores de `GameConfig.Survival`.

---

## 1. Regras fixas

| Parâmetro | Valor | Observação |
| --- | --- | --- |
| `MotoLevel` | 3 | Moto fixa, 152 km/h — progressão de moto não existe aqui |
| `AreaId` | 1 | Só o Centro |

Como moto e mapa são fixos, toda a progressão da partida vem das [habilidades](habilidades.md).

---

## 2. O relógio

| Parâmetro | Valor |
| --- | --- |
| `StartTime` | 60 s |
| `MaxTime` | 120 s (teto) |
| `BonusStart` | 30 s na primeira entrega |
| `BonusStep` | –1 s a cada entrega |
| `BonusMin` | 15 s |
| `BreakTime` | 1,5 s entre uma entrega e o próximo pedido |

O bônus por entrega encolhe de 30 s até 15 s, atingindo o mínimo por volta da **16ª entrega**. A partir daí cada entrega devolve sempre 15 s — enquanto a dificuldade continua subindo.

```
Entrega   1    2    3    4   ...   15   16   17   18  ...
Bônus    30   29   28   27   ...   16   15   15   15  ...
```

Esse é o motor da partida: o teto de 120 s significa que acumular tempo tem limite, então a corrida sempre aperta.

---

## 3. Tamanho dos pedidos

| Parâmetro | Valor |
| --- | --- |
| `RouteMin` | 1.100 studs |
| `RouteMax` | 2.000 studs |
| `RouteTries` | 12 tentativas |
| `RouteFactor` | 1,35 (estimativa por linha reta, só se não achar rota) |

A distância é medida pelo caminho das ruas (moto → restaurante → cliente), não em linha reta. Como o bônus de tempo é fixo por entrega, todo pedido precisa ter tamanho parecido — o config mira **20 a 35 segundos de moto**.

---

## 4. Escalada de dificuldade

Aplicada no cliente, pelo `WorldFX`. Tudo escala com o número de entregas concluídas.

| Elemento | Por entrega | Teto | Teto atingido em |
| --- | --- | --- | --- |
| Volume de trânsito | +12% | 3× | ~17ª entrega |
| Velocidade do trânsito | +2,5% | 1,4× | ~16ª entrega |
| Pedestres por quarteirão | +0,3 (base 2) | 6 | ~14ª entrega |
| Pedestres atravessando a rua | +0,6 | 14 | ~23ª entrega |
| Perigos no caminho | +1,5 | 24 | ~16ª entrega |

### 4.1 Espaçamento

| Parâmetro | Valor |
| --- | --- |
| `StartSpacing` | 90 studs |
| `SpacingPerLevel` | –3,5 studs |
| `MinSpacing` | 30 studs |

O espaço mínimo entre perigos encolhe a cada entrega. Isso é o que mantém a pressão subindo mesmo depois que o número sorteado de perigos passa do que caberia no trecho — sem isso, o teto de 24 perigos travaria a dificuldade por volta da 16ª entrega.

---

## 5. Eventos

Sorteados no servidor a cada pedido.

| Parâmetro | Valor |
| --- | --- |
| `StartAt` | 3 — eventos começam a partir da 4ª entrega |
| `ChancePerDelivery` | +5% por entrega |
| `MaxChance` | 40% dos pedidos |

### 5.1 Engarrafamento
`JamSeconds = 25` — carros parados nas ruas do caminho por 25 segundos.

### 5.2 Blitz
| Parâmetro | Valor |
| --- | --- |
| `BlitzLimitKmh` | 60 km/h na barreira |
| `BlitzPenalty` | 3 s descontados do relógio |

A blitz é o único momento do modo em que **ir devagar é a jogada certa**. Com moto nível 3 a 152 km/h, passar a 60 exige frear de verdade — e 3 segundos num relógio que dá 15 por entrega é caro.

---

## 6. Como a partida se desenrola

```
Entregas 1–3     relógio sobe, dificuldade baixa, sem eventos
                 jogador acumula até o teto de 120 s

Entregas 4–15    eventos começam e a chance sobe
                 bônus caindo de 27 s para 16 s
                 trânsito, pedestres e perigos subindo

Entrega 16+      bônus travado em 15 s
                 dificuldade no teto, mas espaçamento ainda encolhendo
                 o relógio passa a cair
```

A primeira escolha de habilidade acontece na 5ª entrega, bem no ponto em que os eventos começam a aparecer.

---

## 7. Limite de requisições

`GameConfig.RateLimits.Survival = 1` — uma requisição por segundo.

---

## 8. Pontos em aberto

- [ ] Como a pontuação final é registrada no `LeaderboardManager`?
- [ ] A Sobrevivência dá dinheiro para o modo livre, ou é economia separada?
- [ ] As habilidades escolhidas persistem entre partidas, ou zeram? (O atributo `Abilities` é salvo no perfil, o que sugere persistência — confirmar.)
