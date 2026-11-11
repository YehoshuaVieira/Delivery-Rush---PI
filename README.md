# 🛵 Deliver Rush

> Jogo de entregas de moto para Roblox. Cinco bairros, uma moto que evolui, e um modo Sobrevivência contra o relógio.

![Engine](https://img.shields.io/badge/engine-Roblox-red)
![Linguagem](https://img.shields.io/badge/linguagem-Luau-blue)
![Status](https://img.shields.io/badge/status-jogável-green)

---

## Sumário

- [Sobre](#sobre)
- [Os dois modos](#os-dois-modos)
- [Documentação](#documentação)
- [Estrutura do código](#estrutura-do-código)
- [Configuração](#configuração)
- [Equipe](#equipe)

---

## Sobre

O jogador controla um entregador de moto numa cidade dividida em cinco bairros. Entregas pagam conforme a distância, a velocidade e o bairro; o dinheiro compra níveis de moto e desbloqueia bairros novos, que pagam mais.

A moto é **uma só** e evolui por níveis — não existe troca de veículo. O nível define velocidade máxima e aceleração.

### Sistemas implementados

| Sistema | Módulo responsável |
| --- | --- |
| Pedidos e pagamento | `OrderManager`, `PaymentCalculator` |
| Progressão de moto e bairros | `ShopManager`, `UpgradeConfig`, `AreaConfig` |
| Modo Sobrevivência | `SurvivalManager`, `AbilityConfig` |
| Perigos e taxas | `IncidentManager` |
| Ciclo dia/noite | `DayNightCycle` |
| Clima | `WeatherManager`, `WeatherFX` |
| Missões | `MissionManager`, `MissionConfig` |
| Cosméticos e Garagem | `CosmeticManager`, `CosmeticConfig` |
| Ranking ao vivo | `LeaderboardManager`, `LiveBoardController` |
| Validação anti-exploit | `AntiExploitValidation` |
| Persistência | `PlayerDataManager` |
| Telemetria | `Analytics` |

---

## Os dois modos

### Sobrevivência — o modo jogável

Ao entrar, o jogador vê um menu e joga a Sobrevivência: pedidos em sequência, aceitos sozinhos, contra **um relógio só**. Cada entrega soma tempo, mas o bônus diminui a cada entrega. O relógio zerou, acabou a partida.

Só o Centro, moto fixa no nível 3, sem dinheiro, sem oficina, sem bairros. A cada 5 entregas o jogador escolhe 1 entre 3 **habilidades**, que valem até o fim da partida. O que se acumula é o recorde de entregas, salvo e exibido no ranking da praça.

→ [Modo Sobrevivência](docs/sistemas/sobrevivencia.md)

### História — desativado

O loop antigo de dinheiro, Oficina e bairros. O código continua no projeto (`OrderManager`, `ShopManager`, `AreaConfig`, `UpgradeConfig`), mas **só roda quando o atributo `GameMode` do jogador é `"Story"`** — o que não acontece em jogo hoje.

A documentação de economia descreve esse modo. Vale como referência do que existe no código, não do que o jogador encontra.

→ [Economia e Progressão](docs/sistemas/economia-e-progressao.md)

---

## Documentação

| Documento | Conteúdo |
| --- | --- |
| [Game Design](docs/game-design.md) | Visão geral, loop, os dois modos |
| [Economia e Progressão](docs/sistemas/economia-e-progressao.md) | Bairros, níveis de moto, cálculo de pagamento |
| [Moto e Manobras](docs/sistemas/moto-e-manobras.md) | Pilotagem, grau, turbo, salto, fora de pista |
| [Modo Sobrevivência](docs/sistemas/sobrevivencia.md) | Relógio, escalada de dificuldade, eventos |
| [Habilidades](docs/sistemas/habilidades.md) | As 14 cartas, raridades, sorteio |
| [Missões e Garagem](docs/sistemas/missoes-e-garagem.md) | Missões diárias, estrelas, motos cosméticas |
| [Perigos e Taxas](docs/sistemas/perigos-e-taxas.md) | Obstáculos, multas, clima |
| [Rotas e Rede de Ruas](docs/sistemas/rotas.md) | Grafo das ruas, Dijkstra, custo de becos |
| [Arquitetura](docs/arquitetura.md) | Módulos, divisão client/server, persistência |
| [Contribuição](CONTRIBUTING.md) | Branches, commits, padrões |

---

## Estrutura do código

```
ServerScriptService/
├── GameServer                  (Script — bootstrap)
├── PlayerDataManager           persistência e perfil
├── OrderManager                geração e validação de pedidos
├── ShopManager                 compras de nível e bairro
├── MotoManager                 estado e spawn da moto
├── SurvivalManager             modo Sobrevivência
├── IncidentManager             colisões, multas, perigos
├── MissionManager              missões
├── CosmeticManager             skins e carenagens
├── LeaderboardManager          ranking
├── DayNightCycle               ciclo de horas
├── WeatherManager              sol e chuva
├── AntiExploitValidation       checagem de velocidade e tempo
└── Analytics                   telemetria

ReplicatedStorage/Modules/
├── GameConfig                  parâmetros gerais
├── AreaConfig                  os cinco bairros
├── UpgradeConfig               os seis níveis de moto
├── AbilityConfig               as 14 habilidades
├── MissionConfig               missões
├── CosmeticConfig              cosméticos
├── PaymentCalculator           cálculo do pagamento
├── RoadGraph                   grafo das ruas
├── RoadMap                     mapa de ruas
├── MotoSignals                 eventos da moto
├── UIKit                       componentes de UI
├── Format                      formatação de números e texto
└── Creditos                    créditos

StarterPlayer/StarterPlayerScripts/
├── MotoController              pilotagem e input
├── RouteGuide                  rota até o destino
├── AreaVisuals                 visual por bairro
├── WorldFX                     trânsito, pedestres, perigos
├── WeatherFX                   chuva
└── AudioFX                     som

StarterGui/
├── HUD/HUDController
├── MenuGui/MenuController
├── ShopGui/ShopController
├── AreasGui/AreasController
├── AbilityGui/AbilityController
└── LiveBoard/LiveBoardController

ServerStorage/Tools/            ferramentas de autoria (não rodam em produção)
├── MapBuilder                  + Helpers, Blocks, Data, Obstacles,
│                                 Restaurants, FoodProps, Passagem, Acabamento
├── MotoBuilder
├── SkinBuilder
└── AcabamentoMoto
```

---

## Configuração

Todo o balanceamento vive em `ReplicatedStorage/Modules/`. Para ajustar o jogo, mexa nos configs, não nos managers.

### Antes de publicar

> ⚠️ **`GameConfig.Data.DinheiroDeTeste` está em `50000`.** O comentário do próprio arquivo diz para deixar `nil`. Vale conferir se isso é intencional. O mesmo para `EstrelasDeTeste = 20`.

> ⚠️ **`GameConfig.Data.DataStoreName` não pode ser renomeado.** Trocar o nome zera o progresso de todos os jogadores.

---

## Equipe

| Nome | Função | GitHub |
| --- | --- | --- |
| [Nome] | [Função] | [@usuario](https://github.com/usuario) |

---

## Licença

[Definir]
