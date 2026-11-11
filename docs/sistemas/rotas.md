# Rotas e Rede de Ruas

Como o jogo calcula o caminho pelas ruas. Módulo `RoadGraph`.

Usado em dois lugares: a **trilha no chão** (cliente, via `RouteGuide`) e o **prazo dos pedidos** (servidor, via `OrderManager`).

---

## 1. De onde vem a rede

Cada bairro carrega um atributo `RoadLines` — uma string que descreve as ruas daquela área. O `RoadGraph` lê esses atributos e monta o grafo.

A escolha de guardar as ruas como **atributo** e não como instâncias resolve um problema real: atributos chegam ao cliente mesmo com `StreamingEnabled` ligado. Se a rede dependesse das partes do mapa, o cliente não conseguiria calcular rota para um trecho ainda não carregado.

### 1.1 Formato da linha

```
alongX, coord, lo, hi, width, alley
```

| Campo | Significado |
| --- | --- |
| `alongX` | `1` = rua no eixo X, `0` = no eixo Z |
| `coord` | Posição no eixo perpendicular |
| `lo`, `hi` | Início e fim do trecho |
| `width` | Largura da rua |
| `alley` | `1` = beco |

As ruas são todas alinhadas aos eixos — não há diagonais. Coerente com o mapa gerado por `MapBuilder`.

---

## 2. Construção do grafo

### 2.1 Agrupamento

Trechos na mesma linha (mesmo eixo e mesma coordenada arredondada) são agrupados. A largura vira o máximo entre eles, e a linha só é considerada beco se **todos** os trechos forem beco.

### 2.2 Fusão de trechos

Trechos adjacentes ou sobrepostos na mesma linha são fundidos num segmento só. O critério é `span[1] <= cur.B + 1` — tolerância de 1 stud.

### 2.3 Cruzamentos

Para cada par de segmentos perpendiculares, o código testa se eles se cruzam, considerando a largura das duas ruas:

```lua
x >= a.A - b.Width/2 - 1 and x <= a.B + b.Width/2 + 1
```

A tolerância de meia largura mais 1 faz com que uma rua que **termina na borda** de outra também conte como cruzamento — sem isso, ruas sem saída que encostam numa avenida ficariam desconectadas do grafo.

### 2.4 Arestas

Cada segmento vira uma sequência de nós ordenados, com arestas entre nós vizinhos. O custo é a distância multiplicada pelo fator do tipo de via.

---

## 3. Custo dos becos

```lua
local ALLEY_COST = 1.6
```

Becos custam 60% a mais no grafo. O comentário do código diz: *beco só entra na rota se compensar bem*.

Há uma segunda penalidade na projeção (seção 4): beco conta 1,5× mais longe ao escolher o ponto de entrada na rede.

As duas juntas fazem com que a rota prefira avenidas e só corte por beco quando o ganho for substancial. É o que impede a trilha de mandar o jogador para vielas a cada pedido.

---

## 4. Projeção

```lua
project(graph, pos)
```

Encontra o ponto da rede mais próximo de uma posição qualquer — necessário porque jogador e destino raramente estão exatamente em cima de uma rua.

A distância de um beco é multiplicada por 1,5 antes da comparação, pelo mesmo motivo da seção anterior.

---

## 5. Cálculo da rota

```lua
RoadGraph.Route(graph, from, to)   --> lista de pontos no chão, ou nil
RoadGraph.Length(graph, from, to)  --> comprimento em studs, ou nil
```

**Dijkstra com heap binário.** Os nós temporários de origem e destino recebem os ids `0` e `-1` e são ligados aos dois nós vizinhos no segmento onde caíram.

Caso especial: se origem e destino projetam no **mesmo segmento**, uma aresta direta entre eles é inserida — evita que a rota dê a volta no quarteirão para ir até a porta ao lado.

A busca para assim que `-1` sai do heap, sem explorar o resto do grafo.

### 5.1 Saída

`Route` devolve a lista de pontos no chão, descartando pontos a menos de 0,5 stud de distância entre si, e acrescenta a posição final de destino.

`Length` soma a distância do ponto de partida até a rua mais a soma dos trechos. É esse número que alimenta o cálculo de prazo e de pagamento por distância.

---

## 6. Cache

```lua
RoadGraph.Get(areasFolder, allowed)
```

O grafo é cacheado por **conjunto de áreas permitidas**, com a chave sendo os ids ordenados e concatenados (`"1,2,3"`).

Como o desbloqueio é sequencial, existem no máximo 5 combinações reais no modo livre, mais a da Sobrevivência (só a área 1). O cache nunca cresce muito.

---

## 7. Relação com o `RouteFactor`

`GameConfig.Orders.RouteFactor = 1.35` e `GameConfig.Survival.RouteFactor = 1.35`.

O comentário do config da Sobrevivência é explícito: *só se não achar rota: estimativa pela linha reta*. Ou seja, o fator de 1,35 é **fallback**, não um multiplicador aplicado por cima do caminho real.

O comentário no config de Orders é mais ambíguo (*as ruas não são linha reta*). Vale confirmar no `OrderManager` se o comportamento ali é o mesmo.

---

## 8. Notas de performance

**`build` é O(n²) nos segmentos** por causa da detecção de cruzamentos — cada segmento no eixo X é testado contra cada segmento no eixo Z. Roda uma vez por combinação de áreas e fica em cache, então não é problema em runtime. Mas se o mapa crescer muito, o primeiro cálculo de cada nova combinação pode dar um engasgo.

**`project` é O(segmentos) e roda duas vezes por `Route`.** Se o `RouteGuide` recalcular a trilha com frequência alta no cliente, vale conferir o intervalo. Recalcular a cada frame com o grafo de cinco bairros seria caro.

---

## 9. Pontos em aberto

- [ ] Com que frequência o `RouteGuide` chama `Route`?
- [ ] O que acontece no jogo quando `Route` devolve `nil`? Pedido é descartado e sorteado de novo?
- [ ] O `RoadMap` (módulo separado) faz o quê que o `RoadGraph` não faz?
