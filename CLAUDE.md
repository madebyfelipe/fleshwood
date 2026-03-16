# Fleshwoods — CLAUDE.md

Survival horror top-down 2D em **Godot 4.6**. Visuais em **pixelart** (AnimatedSprite2D com spritesheets). Idioma do projeto: **português brasileiro** (UI, comentários, notas de progresso).

> **Nota de transição (2026-03-14):** Pivotado de Polygon2D programáticos para pixelart. Player usa robot asset como placeholder enquanto art final é desenvolvida.

O jogo foi iniciado pelo OpenAI Codex e está sendo continuado aqui. O design completo está documentado abaixo.

---

## Estrutura de arquivos

```
scripts/
  player.gd        → PlayerController (CharacterBody2D) — input, movimento, stamina
  world.gd         → controlador monolítico: ciclo dia/noite, farming, inventário, sobrevivência, evento hostil, UI
  farm_enemy.gd    → FarmEnemy (Area2D) — IA do Goatman, comportamento injetado via Callable
  stamina_ring.gd  → widget de arco (unused por enquanto)
scenes/
  world.tscn       → cena principal (main scene)
  player.tscn      → CharacterBody2D com câmera
  farm_enemy.tscn  → Area2D do Goatman
  tree_source.tscn → Node2D com colisão e área de interação
  vendor.tscn      → Area2D do vendedor
assets/sfx/
ROADMAP.md        → log de sessões e TODOs em português
```

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
| **Darkwatchers** | Homens com terno, não agressivos, servem de informante/tutorial |
| **Vendedor** | Vende itens (munição, sementes, armas), compra colheitas e recursos; fica em ponto fixo |
| **Animais** | Recurso de comida; alguns podem ser mortos |

### Recursos

| Recurso | Uso |
|---|---|
| **Madeira** | Necessário para ligar o gerador |
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
- Comprar: munição, armas melhores, sementes variadas
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
| **Goatman** | Evita luz, evita fogo, sai à noite |
| **Wendigo** | Evita fogo |
| **Mimic** | Se disfarça de animais; pode ser morto |
| **Skinwalker** | Presente nas Planícies (comum) e Correnteza (raro) |

### Eventos

| Evento | Efeito |
|---|---|
| **Noite** | Ligar refletores impede Goatman; requer madeira no gerador; cobre só a fazenda; inimigos mais abundantes |
| **Chuva** | Inimigos menos abundantes; Goatman não aparece à noite |

### Localizações

| Local | Características |
|---|---|
| **Fazenda** | Refletores, cabana com ferramentas, estoque de colheita, composteira |
| **Floresta de Carne** | Goatman pode aparecer de dia (mais lento, incomum); recursos valiosos (incomum) |
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
```

Itens da hotbar (5 slots, teclas 1–5 ou scroll): `bucket`, `axe`, `seeds`, `crop`, `wood`.

Estágios do plot: `EMPTY → STAGE1_DRY → STAGE1_GROWING → STAGE2_DRY → STAGE2_GROWING → MATURE` (40s por estágio; precisa de água para sair de DRY).

### Sistema de inventário

`scripts/inventory_ui.gd` (CanvasLayer layer 10) + `scripts/inventory_data.gd`.

**Slots unificados:** 0–14 = bag (InventoryData) | 15–19 = hotbar (_hotbar de world.gd, referência direta).

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

**Funções de world.gd atualizadas** para verificar bag além da hotbar:
- `_has_item(id)` → hotbar OR bag
- `_get_item_count(id)` → hotbar + bag
- `_remove_item(id, amt)` → hotbar primeiro, drena restante da bag

### Truque das duas salas

Interior da casa em `x ≈ 1856` (fora da área visível). Transição usa fade + teleport + `snap_camera_for_room_transition()`. **Nunca mover** os nós de spawn interior para coordenadas próximas do exterior.

### FarmEnemy (Goatman)

Velocidades: patrol 132 / chase 186 / retreat 260 px/s.
Verificações de visão e luz injetadas como `Callable` por `world.gd`.

Ciclo: `IDLE → WARNING (7.5s, grilos) → ACTIVE → COOLDOWN (12s) → IDLE`

Cheat de debug: segurar `A + R + Q` pula a fase atual.

---

## Status de implementação

### Implementado
- **Player com pixelart** (AnimatedSprite2D, 4 direções de walk, robot asset placeholder)
- Goatman (noturno, foge da luz) — ainda em Polygon2D
- Ciclo dia/noite com overlay
- Farming (18 plots, 6 estágios, água obrigatória)
- Vendedor (sementes por moedas, colheita por moedas)
- Gerador + refletores (madeira como combustível)
- Fome, sede, vida com penalidades de velocidade/stamina
- Colapso com penalidade de moedas
- Hotbar 5 slots
- Transição interior/exterior (fade + teleport)
- 30 árvores com respawn (55s)
- **Inventário** (E abre/fecha): grade 5×3 + hotbar integrada, drag-and-drop Minecraft-like entre todos os slots, descarte por arrastar para fora do painel, divisão de pilha com clique-dir

### Não implementado (próximos passos)
- Darkwatchers (NPC tutorial)
- Wendigo, Mimic, Skinwalker
- Sistema de combate (pistola inicial)
- Chuva (evento)
- Dieta desequilibrada (penalidades por mono-dieta)
- Depreciação de preço de colheita
- 50% de chance de semente extra no colhimento
- Composto e composteira
- Carne como recurso (comida + composto)
- Minérios e Metais
- Localizações além da fazenda (Floresta de Carne, Planícies, Correnteza)
- Progressão de áreas (desbloqueio linear)
- Variedade de plantas compráveis
- Estoque de colheita na cabana

---

## TODOs técnicos ativos

- Validar em runtime os nós criados em `_create_runtime_farm_nodes()`
- Balancear drenagem de fome/sede, custo de sementes, valor de venda, duração do combustível
- Verificar conforto da hotbar com os 5 itens atuais
- Validar Goatman quando gerador liga/desliga durante perseguição
- Considerar dividir `world.gd` se a base for mantida ao expandir localizações
