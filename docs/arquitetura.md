# Arquitetura

Como o código do Deliver Rush está organizado.

---

## 1. Princípios observados no código

**O servidor valida.** `AntiExploitValidation` mede velocidade e tempo em janelas; `GameConfig.RateLimits` limita a frequência de cada ação vinda do cliente. O jogo já parte do princípio de que o cliente mente.

**Configuração separada de lógica.** Todos os números vivem em `ReplicatedStorage/Modules/*Config`. Os managers leem, não hardcodam.

**Física no cliente, verificação no servidor.** `MotoController` roda a pilotagem; o servidor confere depois se a velocidade foi plausível.

---

## 2. Servidor — `ServerScriptService`

| Módulo | Responsabilidade |
| --- | --- |
| `GameServer` | Único `Script` do serviço — bootstrap dos demais |
| `PlayerDataManager` | Perfil, DataStore, autosave |
| `OrderManager` | Sorteio, atribuição e validação de pedidos |
| `ShopManager` | Compra de nível de moto e de bairros |
| `MotoManager` | Estado e spawn da moto |
| `SurvivalManager` | Relógio, escalada e eventos da Sobrevivência |
| `IncidentManager` | Colisões, taxas, perigos |
| `MissionManager` | Missões |
| `CosmeticManager` | Skins, carenagens, Garagem |
| `LeaderboardManager` | Ranking |
| `DayNightCycle` | Ciclo de horas |
| `WeatherManager` | Sol e chuva, sincronizados para todos |
| `AntiExploitValidation` | Checagem de velocidade e tempo |
| `Analytics` | Telemetria |

Todos são `ModuleScript` exceto `GameServer`.

---

## 3. Compartilhado — `ReplicatedStorage/Modules`

### Configuração

| Módulo | Conteúdo |
| --- | --- |
| `GameConfig` | Pedidos, Sobrevivência, pagamento, moto, manobras, taxas, mundo, câmera, dados, anti-exploit, rate limits |
| `AreaConfig` | Os cinco bairros |
| `UpgradeConfig` | Os seis níveis de moto |
| `AbilityConfig` | As 14 habilidades |
| `MissionConfig` | Missões |
| `CosmeticConfig` | Cosméticos |

### Lógica e utilidades

| Módulo | Função |
| --- | --- |
| `PaymentCalculator` | Cálculo do pagamento |
| `RoadGraph` | Grafo das ruas |
| `RoadMap` | Mapa de ruas |
| `MotoSignals` | Eventos da moto |
| `UIKit` | Componentes de UI |
| `Format` | Formatação |
| `Creditos` | Créditos |

---

## 4. Cliente

### `StarterPlayer/StarterPlayerScripts`

| Controller | Função |
| --- | --- |
| `MotoController` | Pilotagem, input, grau, turbo, salto |
| `RouteGuide` | Rota até o destino |
| `AreaVisuais` → `AreaVisuals` | Tint e saturação por bairro |
| `WorldFX` | Trânsito, pedestres, perigos, escalada da Sobrevivência |
| `WeatherFX` | Chuva |
| `AudioFX` | Som |

### `StarterGui`

| GUI | Controller |
| --- | --- |
| `HUD` | `HUDController` |
| `MenuGui` | `MenuController` |
| `ShopGui` | `ShopController` |
| `AreasGui` | `AreasController` |
| `AbilityGui` | `AbilityController` |
| `LiveBoard` | `LiveBoardController` |

Todos `LocalScript`.

---

## 5. Ferramentas de autoria — `ServerStorage/Tools`

Não rodam em produção. São scripts de construção, executados pelos desenvolvedores.

```
MapBuilder
├── Helpers
├── Blocks
├── Data
├── Obstacles
├── Restaurants
├── FoodProps
├── Passagem
└── Acabamento
MotoBuilder
SkinBuilder
AcabamentoMoto
```

O mapa é **gerado por script**, não construído à mão no Studio. Isso explica a estrutura regular de `Map/Areas/AreaN_*/` com as subpastas `Buildings`, `Roads`, `RoadLimits`, `StreetProps`, `Obstacles`, `Customers`, `Restaurants` e `Acabamento`.

> Consequência importante: o `MapBuilder` é código de produção disfarçado de ferramenta. Se ele se perder, o mapa não é reconstruível. Deve ser versionado com o mesmo cuidado que o resto.

---

## 6. Persistência

| Parâmetro | Valor |
| --- | --- |
| DataStore | `iFoodRoblox_PlayerData_v1` |
| `AutosaveInterval` | 120 s |
| `MaxRetries` | 4 |
| `StartingMoney` | 0 |

> ⚠️ **Não renomeie o DataStore.** O comentário no `GameConfig` é explícito: trocar o nome zera o progresso de todos os jogadores.

### 6.1 Formato dos atributos

Dois campos são guardados como string separada por vírgula, com parser próprio:

```lua
AreaConfig.ParseUnlocked("1,2,3")     --> { [1]=true, [2]=true, [3]=true }
AbilityConfig.Parse("shield,jump")    --> { shield=true, jump=true }
```

`ParseUnlocked` sempre inclui a área 1, mesmo se ela não estiver na string.

### 6.2 Flags de teste

```lua
GameConfig.Data.DinheiroDeTeste = 50000   -- comentário diz: "Deixe nil"
GameConfig.Data.EstrelasDeTeste = 20
```

Valem só no Studio e nada é salvo, mas estão ativas. Conferir antes de publicar.

---

## 7. Ponto de atenção: `ServerStorage._Backup`

A pasta contém versões antigas do código — `v3`, `v11` até `v21` — somando cerca de 139 scripts, quase três vezes o tamanho do código vivo.

É controle de versão feito à mão. Depois que o repositório Git estiver funcionando, a pasta pode ser removida: o Git passa a fazer esse trabalho melhor, com diff, histórico e possibilidade de voltar atrás.

Antes de apagar, vale um commit inicial com ela dentro, para que o histórico não se perca.

---

## 8. Convenções observadas

| Elemento | Padrão usado |
| --- | --- |
| Módulos | PascalCase (`OrderManager`) |
| Managers de servidor | sufixo `Manager` |
| Controllers de cliente | sufixo `Controller` |
| Efeitos visuais | sufixo `FX` |
| Configs | sufixo `Config` |
| Ids de dados | minúsculo curto (`shield`, `nitro`) |
| Pastas de área | `AreaN_Nome` |
| Comentários | Português, explicando a intenção e não a sintaxe |

Os comentários do `GameConfig` são particularmente bons — registram o porquê de cada número e os efeitos colaterais de mudá-lo. Vale manter esse padrão.

---

## 9. Versionamento

O código é sincronizado para o disco via **Script Sync** do Studio (`Sync to…` no menu de contexto do Explorador).

| Sincronizar | Não sincronizar |
| --- | --- |
| `ServerScriptService` | `ServerStorage._Backup` |
| `ReplicatedStorage` | O mapa (fica no Team Create) |
| `StarterGui` | |
| `StarterPlayer` | |
| `ServerStorage/Tools` | |

Nenhum script vive dentro de Model ou Part no Workspace, então o Script Sync cobre 100% do código.
