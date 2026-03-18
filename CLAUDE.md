# Fleshwoods — CLAUDE.md

Survival horror top-down 2D em **Godot 4.6**. Visuais em **pixelart** (AnimatedSprite2D com spritesheets). Idioma do projeto: **português brasileiro** (UI, comentários, notas de progresso).

> **Nota de transição (2026-03-14):** Pivotado de Polygon2D programáticos para pixelart. Player usa robot asset como placeholder enquanto art final é desenvolvida.

O jogo foi iniciado pelo OpenAI Codex e está sendo continuado aqui. O design completo está documentado abaixo.

---

## Estrutura de arquivos

```
scripts/
  player.gd               → PlayerController (CharacterBody2D) — input, movimento, stamina
  world.gd                → controlador monolítico (~1500+ linhas): dia/noite, farming, inventário, sobrevivência, inimigos, UI
  farm_enemy.gd           → FarmEnemy (Area2D) — IA do Goatman, comportamento injetado via Callable
  stamina_ring.gd         → widget de arco (unused por enquanto)
  inventory_ui.gd         → InventoryUI (CanvasLayer layer 10) — grade 5×3 + hotbar integrada
  inventory_data.gd       → InventoryData — 15 slots de bag
  darkwatcher_shop_ui.gd  → DarkwatcherShopUI (CanvasLayer layer 11) — loja com grade de slots e feedback
  main_menu.gd            → Menu principal: animação parallax, música, botões
  options_menu.gd         → OptionsMenu (class_name) — volume, resolução, fullscreen; persiste em user://settings.cfg
  asset_manager.gd        → utilitário de cache de texturas (não usado em produção)
  sprite_generator.gd     → utilitário de setup de SpriteFrames (one-shot, não usado em produção)
scenes/
  world.tscn              → cena principal (main scene)
  player.tscn             → CharacterBody2D com câmera
  farm_enemy.tscn         → Area2D do Goatman
  tree_source.tscn        → Node2D com colisão e área de interação
  vendor.tscn             → Area2D do vendedor
  generator.tscn          → cena do gerador
  reflector.tscn          → cena do refletor
  floresta_de_carne.tscn  → cena da Floresta de Carne (subescena embutida em world.tscn)
  main_menu.tscn          → menu principal (cena de entrada do jogo)
  options_menu.tscn       → painel de opções (carregado dinamicamente sobre o menu)
assets/sfx/               → footstep, swingaxe, danger1, chase sequence, main menu, chuva (Rain on Brick), grilos
assets/Characters/        → Prota (idle/run/swing), Wendigo, Goatman, Darkwatcher, Old Man
assets/Misc/              → banner, floodlight, generator, logo, main menu background
ROADMAP.md               → log de sessões e TODOs em português
```

---

## ⚠️ REGRA DE PRIORIDADE MÁXIMA — Controle do canvas pelo usuário

**O usuário SEMPRE tem controle total sobre posição, escala, tamanho e layout dos nós no editor do Godot.**

- **NUNCA** sobrescrever `position`, `size`, `scale`, `pivot_offset`, `offset_*`, anchors ou qualquer propriedade de layout de nós via script em `_ready()` ou qualquer outra função, a menos que o usuário peça explicitamente.
- **NUNCA** chamar `set_anchors_and_offsets_preset()`, `set_position()`, `set_size()` ou equivalentes em nós que o usuário posiciona no canvas.
- Texturas, sprites e recursos visuais devem ser declarados no `.tscn` como `ext_resource`, não carregados via `load()` no script — assim ficam visíveis no editor.
- O script deve cuidar apenas de **lógica e comportamento** (animações de modulate, inputs, sinais). Layout é responsabilidade do `.tscn`.

---

## Convenções obrigatórias

- **GDScript** — sem C#. Tipagem estática sempre que possível.
- **Visuais = Pixelart (AnimatedSprite2D/SpriteFrames)** — usar spritesheets quando asset disponível.
- **Velocidades e distâncias com valores inteiros** (mesmo sendo `float`) para compatibilidade com pixel snap.
- **Input registrado em runtime** via `_ensure_input_actions()` em `player.gd` — não adicionar ações no editor.
- **Português BR** em toda UI, comentários e `progress.md`.
- **Não criar arquivos `.uid` manualmente** — Godot os gera automaticamente.

## Processo de assets (obrigatório)

Mecânicas têm prioridade sobre artwork. Para evitar acoplamento visual quebrado:

1. **Antes de qualquer implementação visual → perguntar ao usuário qual asset usar**
2. **Asset disponível** → usar `AnimatedSprite2D` + `SpriteFrames` com o path confirmado
3. **Asset não disponível** → usar `Polygon2D` como placeholder, marcado com `# PLACEHOLDER`
4. **Nunca assumir** path, dimensões de frame ou número de frames — sempre confirmar com o usuário

### Padrão de placeholder
```gdscript
# PLACEHOLDER — substituir por AnimatedSprite2D quando asset disponível
var body := Polygon2D.new()
body.color = Color(0.4, 0.4, 0.4, 1)
body.polygon = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)
add_child(body)
```

## Configurações do projeto (project.godot)

- Resolução: 1280×720, stretch `canvas_items`
- `snap_2d_transforms_to_pixel = false` (desligado para evitar jitter)
- `snap_2d_vertices_to_pixel = true` (mantém crispness nos polígonos)
- Zoom da câmera: 2× (viewport efetivo 640×360)

---

## Design completo (mapa mental)

### NPCs

| NPC | Comportamento |
|---|---|
| **Tutorial NPC (Caim)** | Velho fazendeiro, dá instruções iniciais via diálogo, morre à noite para dramatismo |
| **Darkwatchers** | Homens com terno, não agressivos, informantes; primeiro abre a loja após o diálogo |
| **Vendedor** | Vende itens (munição, sementes, armas), compra colheitas e recursos; fica em ponto fixo |
| **Animais** | Recurso de comida; alguns podem ser mortos |

### Recursos

| Recurso | Uso |
|---|---|
| **Madeira** | Necessário para ligar o gerador |
| **Trigo (crop)** | Alimento base; pode ser cozinhado em pão (2 trigo = 1 pão) |
| **Pão** | Cozinhado no fogão; restaura +44 fome +8 vida |
| **Carne** | Comida; pode ser usada para fazer composto |
| **Água** | Necessária para colheita |
| **Minérios** | Pode ser vendido |
| **Metais** | Pode ser vendido |

### Mecânicas

#### Combate
- **Altamente desencorajado** — recursos difíceis de encontrar, inimigos muito mais fortes
- Armas: **Pistola** (inicial) → **Revólver** → **Shotgun**

#### Status
- Fome e Sede começam **abaixo de 100%**
- Vida: cura é recurso escasso e caro

#### Progressão
- Recursos escassos; primeiros recursos mais fáceis de coletar
- Progressão linear — novas áreas e mecânicas desbloqueadas conforme o jogador avança

#### Compra e Venda
- Comprar: munição, armas melhores, sementes variadas, lanterna
- Vender: colheitas, recursos do mato (minérios, metais)

#### Plantação
- **50% de chance** de conseguir semente extra a cada colheita
- Possível comprar outros tipos de planta
- Colheitas frequentemente vendidas **perdem valor** (depreciação de mercado)
- **Composto** acelera produção

#### Dieta (sistema de penalidades)
- Comer somente um tipo de alimento **prejudica os status**
- Só vegetais → prejudica a **vida total**
- Só carne → prejudica a **stamina**
- A colheita é tanto alimento quanto fonte de renda — necessário **racionar**

### Antagonistas

| Inimigo | Comportamento |
|---|---|
| **Goatman** | Não spawna na fazenda enquanto o gerador estiver ligado, evita fogo, spawna na floresta da carne a todo momento, porém é mais fraco durante o dia. |
| **Wendigo** | Evita luz, pode spawnar na fazenda durante a noite somente, foge do player caso ele esteja com a lanterna ligada e equipada |
| **Mimic** | Se disfarça de animais; pode ser morto; Sabota o gerador durante a noite |
| **Skinwalker** | Aparece durante a noite, anuncia sua presença e o jogador deve caçá-lo e o espantar antes que ele persiga o player |

### Eventos

| Evento | Efeito |
|---|---|
| **Noite** | Ligar refletores impede Goatman; requer madeira no gerador; cobre só a fazenda; inimigos mais abundantes |
| **Chuva** | Inimigos menos abundantes; Goatman não aparece à noite |

### Localizações

| Local | Características |
|---|---|
| **Fazenda** | Refletores, cabana com ferramentas (fogão, caixa de venda), estoque de colheita, composteira |
| **Floresta de Carne** | Goatman pode aparecer de dia (mais lento, incomum); recursos valiosos (incomum) — cena separada implementada |
| **Planícies** | Coiotes e animais (comum), Skinwalkers (comum), Wendigo (raro) |
| **Correnteza** | Skinwalker (raro), Vendedor fixo |

---

## Arquitetura e API

### PlayerController (`scripts/player.gd`)

Estados de movimento:
| Estado | Velocidade |
|---|---|
| NORMAL | 96 px/s |
| SPRINTING | 300 px/s |
| EXHAUSTED | 52 px/s |

**API pública:**
```gdscript
set_survival_modifiers(speed_mult: float, stamina_regen_mult: float)
set_held_item(item_id: String, short_label: String, color: Color)
set_movement_locked(is_locked: bool)
snap_camera_for_room_transition()
restore_camera_after_room_transition()
get_stamina_ratio() -> float
get_facing_direction() -> Vector2
is_sprinting() -> bool
is_exhausted() -> bool
is_stamina_on_cooldown() -> bool
```

### world.gd — constantes de balanço (alterar com cuidado)

```gdscript
DAY_DURATION = 180.0 / NIGHT_DURATION = 135.0
HUNGER_DRAIN_PER_SECOND = 0.22 / THIRST_DRAIN_PER_SECOND = 0.34
HEALTH_DECAY_PER_SECOND = 5.5 / HEALTH_RECOVERY_PER_SECOND = 1.2
SELL_PRICE = 12 / VENDOR_SEED_BUNDLE_COST = 60
GENERATOR_FUEL_PER_WOOD = 42.0 / GENERATOR_FUEL_DRAIN_PER_SECOND = 1.0
REFLECTOR_RADIUS = 212.0
FLASHLIGHT_RANGE = 320.0 / FLASHLIGHT_CONE_DOT = 0.82 (cone ~70 graus)
LANTERN_BATTERY_MAX = NIGHT_DURATION / 4.0  (~33.75s por carga)
STOVE_COOK_DURATION = 30.0 / STOVE_WHEAT_COST = 2
BREAD_HUNGER_RESTORE = 44.0 / BREAD_HEALTH_RESTORE = 8.0
MIMIC_SPEED = 55.0 / MIMIC_FLEE_SPEED = 170.0 / MIMIC_SABOTAGE_RADIUS = 40.0
WENDIGO_PATROL_SPEED = 80.0 / WENDIGO_CHARGE_SPEED = 255.0 / WENDIGO_PATROL_DURATION = 60.0
MAX_ANXIETY_DISTANCE = 380.0 / MIN_ANXIETY_DISTANCE = 70.0
```

Itens da hotbar (5 slots, teclas 1-5 ou scroll): `bucket`, `axe`, `seeds`, `crop`, `wood`.
Itens adicionais (bag/compra): `pao` (pão, cozinhado no fogão), `lanterna` (comprável no Darkwatcher).

Estágios do plot: `EMPTY → STAGE1_DRY → STAGE1_GROWING → STAGE2_DRY → STAGE2_GROWING → MATURE` (40s por estágio; precisa de água para sair de DRY).

### Sistema de inventário

`scripts/inventory_ui.gd` (CanvasLayer layer 10) + `scripts/inventory_data.gd`.

**Slots unificados:** 0-14 = bag (InventoryData) | 15-19 = hotbar (_hotbar de world.gd, referência direta).

Os dicionários têm formatos diferentes internamente:
- Hotbar: `{"id", "label", "count"}`
- Bag: `{"id", "name", "quantity"}`

Os helpers `_slot_id/qty/name`, `_write_slot`, `_clear_slot` normalizam o acesso. `_move_unified` e `_split_unified` funcionam transparentemente entre qualquer par de slots.

**API pública do InventoryUI:**
```gdscript
set_hotbar(hotbar: Array)                           # passar _hotbar de world.gd uma vez
open(data: InventoryData, selected_hotbar: int)     # abre painel
cancel_drag()                                       # cancela drag em andamento
signal closed                                       # emitido ao fechar
```

**Funções de world.gd** para verificar bag além da hotbar:
- `_has_item(id)` → hotbar OR bag
- `_get_item_count(id)` → hotbar + bag
- `_remove_item(id, amt)` → hotbar primeiro, drena restante da bag

### DarkwatcherShopUI (`scripts/darkwatcher_shop_ui.gd`)

CanvasLayer layer 11. Instanciado via `_init(get_coins, try_buy, can_buy, items)` — callbacks injetados. Grade de `COLS=3` slots com ícone/placeholder, nome e preço. Feedback temporário (2.5s) em verde/vermelho.

**API pública:**
```gdscript
open()            # exibe a loja e atualiza moedas
signal closed     # emitido ao fechar (ESC)
```

### OptionsMenu (`scripts/options_menu.gd`)

`class_name OptionsMenu`. Persiste em `user://settings.cfg`. Resoluções: 1280x720, 1366x768, 1600x900, 1920x1080, 2560x1440.

**Método estático:**
```gdscript
OptionsMenu.aplicar_configuracoes_salvas()  # chamado no _ready do main_menu sem abrir o painel
```

### Truque das duas salas

Interior da casa em `x ≈ 1856` (fora da área visível). Transição usa fade + teleport + `snap_camera_for_room_transition()`. **Nunca mover** os nós de spawn interior para coordenadas próximas do exterior.

### FarmEnemy (Goatman)

Velocidades: patrol 132 / chase 186 / retreat 260 px/s.
Verificações de visão e luz injetadas como `Callable` por `world.gd`.

Ciclo: `IDLE → WARNING (7.5s, grilos) → ACTIVE → COOLDOWN (12s) → IDLE`

Cheat de debug: segurar `A + R + Q` pula a fase atual.

### Wendigo

Estados: `INACTIVE → PATROLLING (60s, rota de waypoints) → CHARGING (7s, persegue player) → INACTIVE`.
Cooldown entre aparições: 38-65s aleatório. Número de aparições escala por noite. Foge da lanterna equipada.

### Mimic

Estados: `INACTIVE → APPROACHING (caminha ao gerador) → FLEEING → DONE`.
Aparece 1x por noite entre 30-80s após o início. Sabota o gerador ao chegar a 40px. Foge do player a 96px.

### Tutorial NPC (Caim) e Darkwatcher

Fases do tutorial: `AWAIT_APPROACH → IN_DIALOGUE → IDLE → NIGHT_WARN → NIGHT_RUN_GENERATOR → DYING → DEAD`
Fases do Darkwatcher: `INACTIVE → AWAIT_APPROACH → IN_DIALOGUE → DONE`

O Darkwatcher abre a `DarkwatcherShopUI` após o diálogo e dá moedas iniciais ao jogador.

### Sistema de Ansiedade

Ativado enquanto um inimigo está em perseguição ativa. Volume do áudio proporcional à distância: máximo a 70px, zero a 380px.

**Componentes visuais/câmera** (todos em `world.gd` + `player.gd`):

| Componente | Descrição |
|---|---|
| `_tint_rect` (ColorRect) | Sobreposição vermelha escura — `Color(0.35, 0.03, 0.03, intensity × 0.18)` |
| `_vignette_rect` (ColorRect + ShaderMaterial) | Vinheta pitch-black nas bordas — shader `smoothstep`, escurece de 55% a 90% no máximo |
| Camera shake (`player.gd`) | `camera.offset` com dois senos defasados (freq 22Hz, max 5px) |
| Camera zoom-in (`player.gd`) | Zoom base de 2.0 → 2.45 conforme intensidade, com pulso sutil (mag 0.04, freq 1.8) |

**Fluxo em `world.gd → _update_anxiety(delta)`:**
1. Calcula `chase_intensity = 1.0 - clamp((dist - 70) / (380 - 70), 0, 1)` para cada inimigo ativo (Goatman e Wendigo)
2. Lerpa `_anxiety_current` → `target_intensity` (fade-in 2.0/s, fade-out 1.2/s)
3. Envia `_anxiety_current` ao shader e ao `player.set_anxiety_intensity()`

**API:**
```gdscript
# em player.gd
set_anxiety_intensity(intensity: float)  # 0.0–1.0; controla shake + zoom
```

**CanvasLayer:** layer 2 (acima da NightRect em layer 1, abaixo da HUD em layer 10).

**Regra de câmera:** `camera.global_position` só é forçado nas transições de sala (`delta == 0.0`). Durante o jogo normal, apenas `camera.offset` e `camera.zoom` são tocados — nunca forçar `global_position` por frame (causa jitter).

---

## Status de implementação

### Implementado
- **Menu principal** (`main_menu.tscn`) — animação parallax, música com fade-in, Novo Jogo / Opções / Sair
- **Menu de opções** — volume, resolução, fullscreen; salvo em `user://settings.cfg`
- **Player com pixelart** (AnimatedSprite2D, 4 direções de walk, robot asset placeholder)
- **Tutorial NPC (Caim)** — diálogo em 8 linhas, morre à noite, fases controladas por enum
- **Darkwatcher NPC** — diálogo em 5 linhas + abertura da loja com moedas iniciais
- **Loja do Darkwatcher** (DarkwatcherShopUI) — grade de compra com feedback, lanterna disponível
- **Lanterna** — item comprável, bateria ~33.75s (1/4 da noite), cone de ~70 graus
- **Fogão (Stove)** — interior da cabana; 2 trigo → 1 pão em 30s
- **Pão** — item que restaura +44 fome +8 vida
- **Goatman** (noturno, foge da luz; aparece de dia na Floresta mais lento) — ainda em Polygon2D
- **Wendigo** — INACTIVE/PATROLLING/CHARGING, escala por noite, foge da lanterna
- **Mimic** — INACTIVE/APPROACHING/FLEEING/DONE, sabota gerador à noite
- **Floresta de Carne** — cena separada (`floresta_de_carne.tscn`), portal de entrada/saída
- **Sistema de Ansiedade** — áudio chase sequence proporcional à proximidade do inimigo
- Ciclo dia/noite com overlay
- Farming (18 plots, 6 estágios, água obrigatória)
- Vendedor (sementes por moedas, colheita por moedas)
- Gerador + refletores (madeira como combustível; cenas separadas `generator.tscn`, `reflector.tscn`)
- Fome, sede, vida com penalidades de velocidade/stamina
- Colapso com penalidade de moedas
- Hotbar 5 slots
- Transição interior/exterior (fade + teleport)
- 30 árvores com respawn (55s)
- **Inventário** (E abre/fecha): grade 5×3 + hotbar integrada, drag-and-drop Minecraft-like, descarte fora do painel, divisão de pilha com clique-dir

### Não implementado (próximos passos)
- Skinwalker
- Sistema de combate (pistola inicial → revólver → shotgun)
- Chuva (evento)
- Dieta desequilibrada (penalidades por mono-dieta)
- Depreciação de preço de colheita
- 50% de chance de semente extra no colhimento
- Composto e composteira
- Carne como recurso (comida + composto)
- Minérios e Metais
- Localizações além da fazenda e Floresta (Planícies, Correnteza)
- Progressão de áreas (desbloqueio linear)
- Variedade de plantas compráveis
- Estoque de colheita na cabana

---

## TODOs técnicos ativos

- Validar em runtime os nós criados em `_create_runtime_farm_nodes()`
- Balancear drenagem de fome/sede, custo de sementes, valor de venda, duração do combustível
- Balancear timers do Wendigo e Mimic (cooldown, escala por noite)
- Validar Goatman quando gerador liga/desliga durante perseguição
- Considerar dividir `world.gd` se a base for mantida ao expandir localizações
- `asset_manager.gd` e `sprite_generator.gd` são utilitários — avaliar se devem ser deletados ou mantidos
