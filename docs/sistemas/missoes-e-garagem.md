# Missões e Garagem

Economia paralela à do modo livre: missões diárias da Sobrevivência pagam **estrelas**, e estrelas compram motos cosméticas na Garagem.

Valores de `MissionConfig` e `CosmeticConfig`.

---

## 1. As duas economias

O jogo tem dois circuitos de recompensa que não se misturam:

| Circuito | Moeda | Fonte | Gasto |
| --- | --- | --- | --- |
| Progressão | Dinheiro | Entregas no modo livre | Níveis de moto e bairros |
| Cosmético | Estrelas | Missões diárias da Sobrevivência | Motos da Garagem |

Nenhuma moto da Garagem afeta desempenho. Velocidade e aceleração vêm só do `UpgradeConfig`.

---

## 2. Missões diárias

| Parâmetro | Valor |
| --- | --- |
| `PerDay` | 3 missões por dia |
| `ResetHourUTC` | 3 (meia-noite em Brasília) |
| `SpareSeconds` | 30 s — critério da missão "folga" |

As missões são da **Sobrevivência**, não do modo livre.

### 2.1 Catálogo

| Id | Missão | Meta | Estrelas | Sorte |
| --- | --- | --- | --- | --- |
| `entregas` | Faça N entregas | 15 | 1 | |
| `partida` | Faça N entregas numa só partida | 8 | 2 | |
| `limpas` | Faça N entregas seguidas sem bater | 5 | 2 | |
| `folga` | Entregue N vezes com 30 s ou mais no relógio | 6 | 1 | |
| `partidas` | Jogue N partidas | 3 | 1 | |
| `habilidades` | Escolha N habilidades | 4 | 1 | |
| `chuva` | Faça N entregas na chuva | 3 | 2 | ✓ |
| `blitz` | Passe por N blitz sem multa | 1 | 2 | ✓ |

### 2.2 Sorteio

```lua
MissionConfig.Pick(day, userId)
```

O sorteio é **determinístico**, com semente derivada do dia e do `UserId`:

```lua
Random.new(day * 100003 + math.abs(userId) % 100003)
```

Isso garante que o mesmo jogador veja as mesmas três missões o dia inteiro, mesmo trocando de servidor, sem precisar salvar nada. Jogadores diferentes recebem conjuntos diferentes no mesmo dia.

### 2.3 Regra da sorte

Missões marcadas com `Luck = true` dependem de condições que o jogador não controla — a chuva aparecer, uma blitz ser sorteada. O sorteio garante **no máximo uma por dia**. Se uma segunda for sorteada, é descartada e o sorteio continua.

Com 8 missões no total e só 2 marcadas como sorte, o pool nunca esvazia antes de completar as 3.

### 2.4 Virada do dia

```lua
MissionConfig.Day(now)        -- número do dia
MissionConfig.NextReset(now)  -- timestamp do próximo reset
```

O dia é calculado deslocando o timestamp em 3 horas antes de dividir por 86400. Vira à meia-noite de Brasília independentemente do fuso de quem joga.

---

## 3. A Garagem

| Moto | Custo | Skin | Descrição |
| --- | --- | --- | --- |
| Naked 3 | Grátis | `Naked3` | Naked de rua, 3 cilindros |
| Scooter Retrô | 10 ⭐ | `ScooterRetro` | Scooter clássica |
| Café Racer | 20 ⭐ | `CafeRacer` | Clássica de garagem |
| Hiper Elétrica | 35 ⭐ | `HiperEletrica` | Superesportiva elétrica |
| Conceito Cyber | 50 ⭐ | `ConceitoCyber` | Moto-conceito futurista |

`DefaultSkin = "Naked3"` — a primeira é a padrão e é grátis.

Cada item carrega uma `Color` usada na UI. Os modelos 3D ficam em `ServerStorage.MotoSkins`, montados pelo `Tools.MotoBuilder`, e os créditos dos modelos estão em `Modules.Creditos`.

### 3.1 Custo total

Desbloquear tudo custa **115 estrelas**.

As três missões do dia rendem entre 3 e 6 estrelas, com média em torno de 4,5. Isso coloca a Garagem completa em aproximadamente **26 dias** de jogo diário — um ciclo de retenção de quase um mês.

Vale conferir se esse é o ritmo pretendido. É longo para um jogo de Roblox, mas coerente se a Garagem for o objetivo de longo prazo.

---

## 4. Estrutura de dados

```lua
CosmeticConfig.Categories        -- array de categorias; hoje só "Moto"
CosmeticConfig.Get(id)
CosmeticConfig.GetCategory(id)
CosmeticConfig.Default(categoryId)   -- primeiro item da categoria
CosmeticConfig.SkinOf(id)            -- nome do modelo, com fallback para DefaultSkin
```

A estrutura em categorias está pronta para mais de uma (capacete, mochila, acessório), mas só `Moto` existe hoje. Adicionar uma categoria nova não exige mudar o `CosmeticManager`, só o config.

---

## 5. Observação sobre nomenclatura

Há três coisas diferentes chamadas de "moto" no projeto:

| Termo | O que é | Onde |
| --- | --- | --- |
| Nível da moto | Desempenho: velocidade e aceleração | `UpgradeConfig` |
| Moto da Garagem | Aparência: modelo 3D | `CosmeticConfig` |
| Moto no mapa | A instância física | `MotoManager` |

Vale padronizar na UI para que o jogador não ache que comprar a Conceito Cyber o deixa mais rápido. Sugestão: chamar o `UpgradeConfig` de **nível** ou **motor**, e reservar "moto" para a aparência.
