--[[
================================================================================
  DELIVERY RUSH — GUIA DO PROJETO (leia antes de mexer)
================================================================================

  Jogo de entregador de moto no Roblox. Linguagem: Luau.
  Este arquivo é a referência rápida. Os números de verdade estão nos configs
  em ReplicatedStorage.Modules — se houver divergência, o config é que vale.

================================================================================
  1. O QUE O JOGADOR ENCONTRA
================================================================================

Ao entrar, cai num MENU com personagem e moto no palco, três botões (Missões,
Garagem, Como jogar) e o botão JOGAR.

SOBREVIVÊNCIA — o modo jogável
------------------------------
Pedidos em sequência, aceitos sozinhos. Só no Centro, moto fixa no nível 3
(152 km/h). Sem dinheiro, sem Oficina, sem bairros.

  RELÓGIO ÚNICO para a partida inteira:
    começa em 60 s, teto de 120 s
    cada entrega soma um bônus: 30 s na 1ª, −1 s por entrega, até o mínimo de 15 s
    (o mínimo é atingido por volta da 16ª entrega)
    o relógio fica parado entre os pedidos (BreakTime = 1,5 s)
    zerou = fim da partida

  TAMANHO DOS PEDIDOS: 1100 a 2000 studs pelo caminho das ruas (moto →
  restaurante → cliente). Como o bônus é fixo, todo pedido precisa ter tamanho
  parecido: cerca de 20 a 35 s de moto.

  HABILIDADES: a cada 5 entregas o jogador escolhe 1 de 3 cartas (14 no total).
  Valem até o fim da partida. 30 s para escolher; passou disso, a primeira é
  escolhida sozinha.

  DIFICULDADE sobe a cada entrega: mais carros (até 3x), trânsito mais rápido
  (até 1,4x), mais pedestres (até 6 por quarteirão), mais gente atravessando
  (até 14) e mais perigos no caminho (até 24). O espaçamento mínimo entre
  perigos encolhe de 90 para 30 studs, então o caminho continua enchendo mesmo
  depois que os tetos são atingidos.

  O TRÂNSITO NÃO PARA pela moto: carro que alcança a moto parada ou
  atravessando acerta e empurra.

  TRILHA no chão mostra o caminho, e perto de cada conversão uma PLACA flutua
  sobre o cruzamento (ESQUERDA / DIREITA).

  EVENTOS a partir da 4ª entrega: a chance sobe 5% por entrega até 40% dos
  pedidos.
    Engarrafamento — carros parados no caminho, com corredor livre no meio (25 s)
    Blitz — limite de 60 km/h conferido no servidor; acima disso perde 3 s

  CHUVA sorteada pelo servidor, igual para todos: a moto freia 22% menos e vira
  14% menos. A habilidade Tração Total anula.

  O QUE FICA entre partidas: o recorde de entregas (salvo, e no ranking da praça).

  MISSÕES DO DIA: 3 por jogador, sorteadas pela data + UserId (as mesmas o dia
  todo, em qualquer servidor), trocam à meia-noite de Brasília. Dão ESTRELAS.

  GARAGEM: estrelas compram motos — só visual, todas andam igual.
    Naked 3 (padrão, grátis), Scooter Retrô (10), Café Racer (20),
    Hiper Elétrica (35), Conceito Cyber (50). Total: 115 estrelas.
    As motos NÃO têm baú (decisão do dono do projeto).

HISTÓRIA — desativado ("em breve")
----------------------------------
O loop antigo de dinheiro, Oficina e Áreas. O código continua no projeto e
funciona, mas só roda quando o atributo GameMode do jogador é "Story".

  5 bairros, desbloqueio sequencial, comprados com dinheiro:
    Centro (grátis, paga 1,0x)          Bairro Nobre (20.000, 2,6x)
    Bairro Residencial (3.000, 1,4x)    Centro Financeiro (50.000, 3,5x)
    Zona Comercial (8.000, 1,9x)
  Total para abrir tudo: 81.000.

  6 níveis de moto (velocidade / aceleração / preço):
    0: 40 studs/s (80 km/h), 30, grátis      3: 76 (152), 54, 4.000
    1: 50 (100), 37, 500                     4: 92 (184), 64, 9.000
    2: 62 (124), 45, 1.500                   5: 110 (220), 76, 20.000
  Total para chegar ao nível 5: 35.000.

  PAGAMENTO = (base + distância × 0,05) × multiplicador do bairro
              × multiplicador de velocidade × gorjeta × (1 + combo)
    base = 60 na Área 1
    velocidade: metade do tempo ideal = 2,5x; no tempo = 1,0x; dobro = 0,4x
    gorjeta: aleatória entre 0,9 e 1,1
    combo: +10% por entrega rápida seguida, teto de +50%. Só conta como combo
           se a entrega teve multiplicador de velocidade >= 1,5
    10% dos pedidos são especiais: pagam o dobro, prazo 25% menor

  O PRAZO é calculado sobre a velocidade do NÍVEL 0 (40 studs/s), não sobre a
  moto atual. É de propósito: moto melhor entrega mais rápido e ganha mais.

================================================================================
  2. PILOTAGEM
================================================================================

Física no cliente (MotoController), validação no servidor.

  DIREÇÃO: a moto vira 140 graus/s, mas na velocidade máxima só 35% disso
  (MinTurnFactor). Acelerar reduz a capacidade de desviar — é o que impede que
  segurar o acelerador seja sempre a jogada certa.

  GRAU E TURBO: segurar Shift (ou o botão GRAU no celular, ou X no controle)
  acima de 15 studs/s levanta a moto. 1,2 s de grau enche o turbo; soltar
  dispara 1,3x de velocidade e 2x de aceleração por 2 s.
    Durante o grau a moto vira pela METADE. Somado ao MinTurnFactor, fazer grau
    em alta velocidade deixa a moto quase sem desvio.
    Passar de 3 s de grau = cai, perde metade da velocidade e zera a carga.
    Salto com 0,3 s de ar também soma carga de turbo.

    ATENÇÃO: o anti-exploit tolera +35% de velocidade e o turbo dá +30%.
    A margem é de 5 pontos. Mexeu no BoostMultiplier, mexa no SpeedTolerance.

  FREIO: 130 studs/s². Soltar o acelerador desacelera só 22 — 6x mais devagar.
  Ré a 35% da velocidade.

  FORA DA PISTA: metade da velocidade e multa CRESCENTE — 3, depois 4, 5, 6...
  a cada 1,6 s fora. Volta ao início depois de 3 s seguidos no asfalto.
  Quem decide se é rua ou calçada é o módulo RoadMap.

  PNEU FURADO: 3 s parado, depois 2 s de imunidade.

  CÂMERA: FOV abre de 70 para 100 conforme a velocidade.

================================================================================
  3. PERIGOS E TAXAS
================================================================================

O jogo não usa perda de multiplicador como punição. Usa dinheiro (História) e
tempo (Sobrevivência).

  TAXAS (História):
    Atropelar pedestre   50   (cooldown 1,5 s)
    Pneu furado          20
    Radar                15   (cooldown 3 s)
    Bater em carro       10   (cooldown 2,5 s, só acima de 12 studs/s)
    Fora da pista         3 + 1 por cobrança

    Atropelar custa 5x mais que bater em carro, e tem o cooldown mais curto da
    tabela. Entrar na multidão a 150 km/h cobra várias vezes seguidas.

  Na SOBREVIVÊNCIA não há multa: a batida só zera a sequência da Entrega
  Perfeita. O custo é o tempo parado.

  PERIGOS DE CHÃO e o que os anula:
    Pregos   → fura o pneu           → Pneus Reforçados
    Buraco   → freia e arremessa     → Pneus Reforçados
    Óleo     → derrapagem 1,3 s      → Tração Total
    Água     → derrapagem 0,8 s      → Tração Total
    Lama     → −55% de velocidade    → Tração Total (vira −15%)
    Lombada  → devagar só balança; rápido dá tranco, pulo e perda de velocidade

  MÓVEIS: carros, pedestres, cones, bolas de demolição (guindaste balançando
  sobre a rua), blitz e engarrafamento.

  Escudo (Campo de Proteção) bloqueia um impacto de qualquer tipo a cada 45 s.
  Modo Fantasma atravessa tudo por 3 s.

================================================================================
  4. AS 14 HABILIDADES
================================================================================

Peso no sorteio: Comum 1,00 | Raro 0,60 | Épico 0,35 | Lendário 0,18.
Não há proteção contra azar — uma partida pode acabar sem nenhuma Lendária.

COMUNS
  Nitro de Emergência    turbo de 4 s quando o relógio chega a 12 s (1x por pedido)
  Entregador Magnético   raio de coleta e entrega 75% maior
  Pneus Reforçados       pregos e buracos não afetam
  Tração Total           óleo e água não derrapam; lama tira 15% em vez de 55%
  Para-choque Reforçado  batidas mantêm 70% da velocidade, carros empurram pela metade

RAROS
  Campo de Proteção      escudo bloqueia o próximo impacto; recarrega em 45 s
  Modo Fantasma     [F]  atravessa tudo por 3 s; recarga 35 s
  Entrega Perfeita       3 entregas seguidas sem bater: a 3ª soma +8 s
  Saída Rápida           turbo de 2,5 s ao começar o pedido e ao pegar a comida

ÉPICOS
  Salto Extremo  [Espaço] salta por cima de obstáculos; recarga 18 s
  Sirene            [Q]   carros e pedestres param num raio de 50 studs por 4 s; recarga 25 s
  Hora Extra             toda entrega soma +3 s

LENDÁRIOS
  Segunda Chance         1x por partida: relógio zerou, ganha +15 s em vez de perder
  Câmera Lenta      [E]  tudo a 30% da velocidade por 5 s; recarga 35 s

  NOTAS DE BALANCEAMENTO
  - Cinco das catorze anulam perigos. As três passivas de chão (Pneus, Tração,
    Para-choque) são todas COMUNS, ou seja, as mais prováveis. Quem junta as
    três fica praticamente imune ao chão — conferir se isso achata a curva.
  - Hora Extra é a mais forte a longo prazo: da 16ª entrega em diante, quando o
    bônus trava em 15 s, +3 s é 20% a mais de relógio por entrega.
  - Tração Total é a única com efeito fora do próprio escopo: anula a chuva.

================================================================================
  5. ONDE FICA CADA COISA
================================================================================

ReplicatedStorage.Modules — CONFIGURAÇÕES (mexa aqui para balancear)
  GameConfig       pedidos, Survival (todo o balanceamento do modo), pagamento,
                   moto, manobras, taxas, fora da pista, mundo, câmera, Data
                   (save), anti-exploit e rate limits
  UpgradeConfig    os 6 níveis de moto: velocidade, aceleração, preço
  AreaConfig       os 5 bairros: preço, multiplicador, pasta e visual
  AbilityConfig    as 14 habilidades: raridade, recarga, duração e textos
  MissionConfig    as missões do dia: lista, metas, textos, estrelas
  CosmeticConfig   a Garagem: motos à venda (preço em estrelas, Skin = modelo
                   em ServerStorage.MotoSkins)
  Creditos         créditos dos modelos 3D (licença CC BY 4.0)
                   *** NÃO REMOVA: a licença exige crédito visível aos jogadores
                   (menu > Como jogar). Vale também se o repositório for público.
  PaymentCalculator  cálculo do pagamento (o servidor paga; o cliente estima)
  RoadGraph        rede de ruas, menor caminho (Dijkstra com heap). Usada pela
                   trilha no chão e pelo prazo dos pedidos. Becos custam 1,6x
                   no grafo e 1,5x na projeção: só entram na rota se compensar.
  RoadMap          diz se uma posição é rua ou calçada/lote (usa BlockRects)
  MotoSignals      eventos locais entre scripts do cliente (Bump, FlatTire,
                   Hazard, Impact)
  UIKit            VISUAL DE TODA A INTERFACE: cores, fontes, ícones, escala,
                   painéis e animações. Mude aqui e muda o jogo inteiro.
  Format           texto no padrão brasileiro ($3.000, 1:05)

  UIKit.IsTouch() diz se é celular. TESTE DE CELULAR NO STUDIO: atributo
  SimularCelular = true no Workspace antes do Play, e diminua a janela.
  Só use fontes NATIVAS do Roblox — família inexistente deixa o texto borrado.

ReplicatedStorage.Assets   modelos 3D: Cars, Bus, Hidrante, NPCMoto,
                           SurvivalHazards, MotoVitrines (motos ancoradas do menu)
ReplicatedStorage.Sounds   biblioteca de sons. Cada Sound tem Gain (volume
                           normalizado) e Start/Stop (trecho que toca).
                           Troque o som aqui, nunca no AudioFX.
ReplicatedStorage.Remotes  eventos cliente <-> servidor

ServerScriptService — SERVIDOR (tudo que envolve dinheiro roda aqui)
  GameServer             inicia os sistemas (a ordem importa). Único Script;
                         o resto é ModuleScript.
  PlayerDataManager      save no DataStore, autosave, trava de sessão
  MotoManager            cria a moto do jogador e prende o piloto nela
  SurvivalManager        relógio, bônus por entrega, eventos, recorde
  OrderManager           sorteia pedidos; na História oferece, confere e paga
  ShopManager            compra de níveis e bairros
  CosmeticManager        Garagem: valida estrelas, guarda a moto escolhida
  MissionManager         missões do dia: sorteio por data, progresso, estrelas
  IncidentManager        taxas: batida, pneu, radar, atropelamento, fora da pista
  AntiExploitValidation  velocidade, teleporte, rate limit, validação da entrega
  LeaderboardManager     ranking global de recordes (painel na praça do spawn)
  WeatherManager         sorteia sol e chuva (atributo Workspace.Clima)
  DayNightCycle          dia (10 min) e noite (3 min), começando às 9h
  Analytics              Creator Dashboard: funil da 1ª sessão, até que entrega
                         o jogador chega, habilidades escolhidas

StarterPlayer.StarterPlayerScripts — CLIENTE
  MotoController   direção, grau/turbo, salto, câmera, habilidades ativas e
                   controles de toque. Os controles de toque PADRÃO do Roblox
                   ficam desligados (DevTouchMovementMode = Scriptable).
  WorldFX          trânsito, pedestres, cones, perigos de chão, bolas de
                   demolição e a escalada da Sobrevivência (lê SurvivalLevel)
  RouteGuide       trilha de setas até o destino e a placa de conversão.
                   Recalcula se a moto se afastar 24 studs da rota.
  AreaVisuals      barreiras dos bairros bloqueados e tint de cada bairro
  WeatherFX        chuva: riscos na tela, gotas, céu carregado e som
  AudioFX          grupos de som (Efeitos com compressor, Interface, Motor,
                   Ambiente) e o mapa impacto -> som

StarterGui — telas MONTADAS EM CÓDIGO (no editor aparecem vazias)
  MenuGui      menu inicial, missões, Garagem, resultado da partida
  HUD          tela do jogo e tutorial
  AbilityGui   escolha de habilidade
  LiveBoard    placar ao vivo, só com 2+ jogadores na Sobrevivência
  ShopGui      Oficina (História)
  AreasGui     bairros (História)

  REGRA DO HUD: só 4 coisas fixas na tela — carteira, pedido, velocímetro e
  menu. O resto aparece e some sozinho.

ServerStorage
  MotoTemplate   esqueleto físico das motos (chassi, colisores, assento, farol,
                 escape)
  MotoSkins      motos jogáveis: Naked3, ScooterRetro, CafeRacer, HiperEletrica,
                 ConceitoCyber. Nivel1..Nivel5 são as antigas da História.
  _FontesMotos   as motos como vieram do Importar 3D (para remontar)
  _Backup        cópias antigas (v3, v11 a v21). NÃO vai para o jogo.
                 Ver aviso 7.

  Tools.MapBuilder     GERADOR DA CIDADE. Ver aviso 1.
                       Build("base"), Build(1..5) ou Build().
                       Grava nos bairros os atributos BlockRects e RoadLines,
                       que são os dados que o cliente precisa mesmo com streaming.
    .Data        tamanho, grade, becos, chances de obstáculo, estilos, nomes de
                 restaurante e de cliente
    .Helpers     funções de construção de peças
    .Blocks      quarteirões: clientes, lotes, prédios, casas, torres, praças
    .Restaurants restaurante detalhado, com variação por bairro
    .FoodProps   mascotes gigantes de comida no telhado
    .Obstacles   visual e dados de cada obstáculo da rua
    .Passagem    garante que toda rua tenha um vão livre (>= 9 studs); remove o
                 perigo mais fraco até sobrar passagem
    .Acabamento  janelas por textura, faixas de pedestre, linha amarela que para
                 no cruzamento, desgaste, calçada, meio-fio, vidros e reboco.
                 Roda sozinho no Build; tem DesfazerFachadas/DesfazerRuas.
  Tools.MotoBuilder      monta uma moto importada no esqueleto do MotoTemplate
                         (rodas que giram, assento, farol, placa) e cria a
                         vitrine do menu
  Tools.SkinBuilder      monta uma moto nova a partir de um modelo 3D
  Tools.AcabamentoMoto   Polir(moto, nivel): fita refletiva, selo da marca,
                         placa Mercosul e pintura com brilho. Rode depois do
                         SkinBuilder.

Workspace.Map    a cidade: 5 bairros de 2240x2240 studs, gerada pelo MapBuilder
Workspace.Motos  as motos dos jogadores (Moto_<UserId>)

================================================================================
  6. AVISOS
================================================================================

1) NÃO rode o MapBuilder sem combinar com o time: ele APAGA e recria a cidade
   inteira. Qualquer edição manual no Workspace.Map se perde.

2) DinheiroDeTeste (GameConfig.Data): número = dinheiro de teste no Studio.
   Nesse modo NADA é salvo, e só vale no Studio. DEIXE EM nil quando terminar.
   EstrelasDeTeste dá estrelas para testar a Garagem, junto com ele.

   *** HOJE ESTÁ EM 50000 E AS ESTRELAS EM 20. Conferir antes de publicar. ***

   Testar missões sem jogar (Studio, durante o Play, barra de comando do servidor):
     game.ServerStorage.TesteMissoes:Fire(jogador, "entregas", 5)
   Forçar chuva:
     workspace:SetAttribute("Clima", "Chuva")

3) DataStoreName (GameConfig.Data): trocar o nome ZERA o progresso de TODOS os
   jogadores. O valor atual é "iFoodRoblox_PlayerData_v1" — nome herdado de uma
   versão antiga do projeto; funciona, mas se o repositório for público vale
   saber que ele está lá.

4) Tudo que mexe em dinheiro é feito no SERVIDOR. O cliente só envia intenções.
   Nenhum remote deve aceitar um valor de progresso vindo do cliente.

5) STREAMING está ligado. No cliente só existem as peças perto da moto. Script
   do cliente que precisa do mapa inteiro deve ler ATRIBUTOS de pastas
   (BlockRects, RoadLines), nunca procurar peças.

6) DESEMPENHO: peça decorativa nova = CanTouch false, e CastShadow false se for
   fina ou pequena. No cliente, o que é movido por script todo quadro (WorldFX)
   é o maior custo: desenhe longe com menos frequência (drawThisFrame) e nunca
   crie ou destrua instâncias por quadro — use os pools.

7) _Backup tem cerca de 139 scripts, quase 3x o tamanho do código vivo (51).
   É controle de versão feito à mão. Com o repositório Git funcionando, essa
   pasta pode ser apagada: o Git faz isso melhor, com diff e histórico.
   Faça um commit com ela antes de apagar, se quiser preservar.

8) Dicas de tecla: use UIKit.Keycap(tecla, { Gamepad = "botão" }). Ela segue o
   dispositivo do jogador e some se a ação não tiver botão naquele dispositivo.

9) Edição em equipe: mudanças em scripts ficam como RASCUNHO até clicar em
   Confirmar (Commit).

10) Antes de mudanças grandes: Arquivo > Baixar uma cópia.

================================================================================
  7. VERSIONAMENTO (Git)
================================================================================

O código é sincronizado para o disco pelo SCRIPT SYNC do Studio: botão direito
no Explorador > Sync to... apontando para a pasta src/ do repositório.

  SINCRONIZE: ServerScriptService, ReplicatedStorage, StarterPlayer,
              ServerStorage/Tools
  NÃO SINCRONIZE: ServerStorage._Backup

  StarterGui NÃO aceita Script Sync — os controllers vivem dentro de ScreenGui,
  que não é Folder nem script. Para versioná-los, exporte a seleção como .rbxmx
  (XML) e extraia os Source, ou copie manualmente.

  O arquivo do lugar (.rbxl) NÃO vai para o Git: é binário, não tem merge, e
  duas pessoas editando o mapa ao mesmo tempo perdem trabalho. Mapa e assets
  ficam no Team Create; só o código vai para o Git.

  Convenção de extensão do Script Sync:
    ModuleScript  -> Nome.luau
    LocalScript   -> Nome.local.luau
    Script        -> Nome.legacy.luau (RunContext legado)
  Não renomeie as extensões: o Studio reimporta com o tipo errado.

================================================================================
  8. CONVENÇÕES DE CÓDIGO
================================================================================

  Módulos             PascalCase (OrderManager)
  Servidor            sufixo Manager
  Cliente             sufixo Controller
  Efeitos visuais     sufixo FX
  Configuração        sufixo Config
  Ids de dados        minúsculo curto (shield, nitro, cafe_racer)
  Pastas de bairro    AreaN_Nome
  Comentários         português, explicando a intenção e não a sintaxe

  Nenhum valor de balanceamento hardcoded fora de ReplicatedStorage.Modules.
  Nenhum RemoteEvent criado fora de ReplicatedStorage.Remotes.

================================================================================
  9. PENDÊNCIAS CONHECIDAS
================================================================================

  [ ] DinheiroDeTeste e EstrelasDeTeste ligados (ver aviso 2)
  [ ] Modo História completo no código, mas sem caminho até ele no jogo
  [ ] Margem de 5 pontos entre o turbo (+30%) e o anti-exploit (+35%)
  [ ] Três passivas Comuns juntas deixam o chão quase irrelevante
  [ ] _Backup ainda no projeto
  [ ] Decidir o nome oficial: o código escreve "DELIVERY RUSH" (selo do baú,
      logo do SkinBuilder, outdoor do Blocks); o lugar no Studio se chama
      "Corrida de Entrega"
]]

return nil
