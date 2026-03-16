# Fleshwoods

Survival horror top-down 2D em **Godot 4.6**. Mecânica central: **stealth e fuga**. O jogador precisa sobreviver noites, administrar recursos escassos e completar missões narrativas para escapar da região.

Visuais em pixelart (AnimatedSprite2D + spritesheets). Idioma do projeto: português brasileiro.

---

## Tecnologia

- **Engine:** Godot 4.6
- **Linguagem:** GDScript (sem C#, tipagem estática)
- **Resolução:** 1280×720, stretch `canvas_items`, câmera com zoom 2×
- **Arte:** pixelart com AnimatedSprite2D/SpriteFrames

---

## Estrutura de arquivos

```
scripts/
  player.gd          → PlayerController (CharacterBody2D): input, movimento, stamina
  world.gd           → controlador principal: ciclo dia/noite, farming, inventário, sobrevivência, UI
  farm_enemy.gd      → FarmEnemy (Goatman, Area2D): IA com comportamento injetado via Callable
  inventory_ui.gd    → UI do inventário (CanvasLayer layer 10): grade 5×3 + hotbar
  inventory_data.gd  → dados do inventário (15 slots bag)
  stamina_ring.gd    → widget de arco de stamina (não usado nas cenas atualmente)
scenes/
  world.tscn         → cena principal
  player.tscn        → CharacterBody2D com câmera
  farm_enemy.tscn    → Area2D do Goatman
  tree_source.tscn   → Node2D com colisão e área de interação
  vendor.tscn        → Area2D do vendedor
assets/sfx/
ROADMAP.md           → fases de desenvolvimento e TODOs
```

---

## Gameplay

### Loop principal

```
Fazenda (base segura)
  → Explorar área perigosa (coletar recursos)
  → Sobreviver à noite
  → Avançar na narrativa com os Darkwatchers
  → Desbloquear próxima área
  → Repetir → ESCAPE
```

### Status do jogador

| Status | Detalhe |
|---|---|
| Vida | Cura escassa e cara; decai sem comida |
| Fome | Começa abaixo de 100%; drena continuamente |
| Sede | Começa abaixo de 100%; drena mais rápido que fome |
| Stamina | Limita sprint; esgotamento reduz velocidade |

**Sistema de dieta:** comer só um tipo de alimento penaliza o jogador. Só vegetais → penaliza vida total. Só carne → penaliza stamina.

### Recursos

| Recurso | Uso |
|---|---|
| Madeira | Combustível do gerador |
| Carne | Comida; pode virar composto |
| Água | Obrigatória para colheita |
| Minérios / Metais | Venda ao Vendedor |
| Colheita | Comida e fonte de renda (sujeita à depreciação) |

### Farming

- 18 plots na fazenda
- 6 estágios: `EMPTY → STAGE1_DRY → STAGE1_GROWING → STAGE2_DRY → STAGE2_GROWING → MATURE`
- 40s por estágio; precisa de água para sair dos estágios `_DRY`
- 50% de chance de semente extra por colheita
- Composto (carne + vegetais) acelera produção

### Ciclo dia/noite

- Dia: 180s | Noite: 135s
- Gerador + refletores protegem a fazenda à noite (consome madeira)
- Chuva: inimigos menos abundantes, Goatman não aparece

---

## Inimigos

| Inimigo | Comportamento |
|---|---|
| **Goatman** | Evita luz e fogo; sai à noite; pode aparecer de dia na Floresta de Carne (mais lento) |
| **Wendigo** | Evita fogo |
| **Mimic** | Se disfarça de animal; pode ser morto |
| **Skinwalker** | Responde a distância, não a som; se disfarça de animal antes de atacar |

### Goatman — estados
`IDLE → WARNING (7.5s) → ACTIVE → COOLDOWN (12s) → IDLE`

Velocidades: patrol 132 / chase 186 / retreat 260 px/s.

---

## NPCs

| NPC | Papel |
|---|---|
| **Darkwatchers** | Homens de terno; não agressivos; entregam missões narrativas e contexto |
| **Vendedor** | Ponto fixo na Correnteza; vende munição, sementes, armas; compra colheitas e recursos |

---

## Localizações

| Local | Características |
|---|---|
| **Fazenda** | Refletores, cabana, farming, gerador; relativamente segura |
| **Floresta de Carne** | Goatman pode aparecer de dia; recursos valiosos |
| **Planícies** | Coiotes e animais (comum); Skinwalker (comum); Wendigo (raro) |
| **Correnteza** | Skinwalker (raro); Vendedor fixo |

---

## Combate

Altamente desencorajado — recursos escassos, inimigos muito mais fortes. Tiro atrai inimigos próximos.

Progressão de armas: **Pistola** (inicial, sem bala) → **Revólver** → **Shotgun**

---

## Inventário

- Tecla `E` abre/fecha
- 15 slots de bag (grade 5×3) + 5 slots de hotbar (teclas 1–5 ou scroll)
- Drag-and-drop entre qualquer par de slots
- Divisão de pilha com clique direito
- Descarte arrastando para fora do painel

---

## Implementado até agora

- Player com pixelart (AnimatedSprite2D, 4 direções, robot placeholder)
- Goatman noturno funcional (foge da luz)
- Ciclo dia/noite com overlay
- Farming completo (18 plots, 6 estágios, água obrigatória)
- Vendedor (sementes por moedas, colheita por moedas)
- Gerador + refletores (madeira como combustível)
- Fome, sede, vida com penalidades de velocidade/stamina
- Colapso com penalidade de moedas
- Hotbar 5 slots
- Transição interior/exterior (fade + teleport + snap de câmera)
- 30 árvores com respawn (55s)
- Inventário completo (bag + hotbar integrada, drag-and-drop, split de pilha)

---

## Roadmap resumido

| Fase | Foco | Status |
|---|---|---|
| **0 — Estabilização** | Balance pass, bugs impeditivos, UX da hotbar | Pendente |
| **1 — Stealth CORE** | Cone de visão, raio de som, estados de alerta, velocidade furtiva | Pendente |
| **2 — Darkwatcher + Missões** | NPC narrativo, sistema de missões, barra de progresso de escape | Pendente |
| **3 — Floresta de Carne** | Primeira área externa, Goatman diurno, recursos valiosos | Pendente |
| **4 — Planícies + Skinwalker** | Segunda área, inimigo com disfarce, animais como recurso | Pendente |
| **5 — Correnteza + Escape** | Área final, Vendedor expandido, condição de escape, tela final | Pendente |
| **6 — Sistemas pendentes** | Chuva, dieta, composto, depreciação de preços, semente extra | Pendente |
| **7 — Combate** | Pistola, munição, knockback, ruído de tiro, upgrades | Pendente |
| **8 — Polish final** | Spritesheets restantes, som por área, partículas, balance final | Pendente |
