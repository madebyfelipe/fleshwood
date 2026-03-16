# Fleshwoods — Roadmap

> Survival horror top-down 2D · Godot 4.6 · GDScript
> Mecânica central: **stealth/fuga** · Objetivo: sobreviver e escapar via missões narrativas

---

## Loop de gameplay

```
Fazenda (base segura)
  → Explorar área perigosa (recurso / evento)
  → Sobreviver à noite
  → Avançar na narrativa (Darkwatcher)
  → Desbloquear próxima área
  → Repetir → ESCAPE
```

---

## Fase 0 — Estabilização

> Base estável antes de qualquer expansão.

- [ ] Balance pass: fome/sede/drain, custo de sementes, combustível do gerador
- [ ] Validar transição interior/exterior (câmera snap, fade)
- [ ] Validar Goatman quando gerador liga/desliga durante perseguição
- [ ] Revisar UX da hotbar (5 slots, scroll, teclas 1–5)

**Critério de saída:** sobreviver 1 dia + 1 noite sem bugs impeditivos.

---

## Fase 1 — Sistema de Stealth ⚠️ PRIORIDADE MÁXIMA

> O jogador sente medo ao se movimentar. Base reutilizada por todos os inimigos futuros.

- [ ] **Cone de visão** nos inimigos — triângulo/arco frontal; detecta jogador dentro do cone
- [ ] **Raio de som** — sprint gera som em raio maior; inimigos ouvem fora do cone
- [ ] **Estados de alerta** — `IDLE → ALERTED (ouviu) → CHASE (viu)`
- [ ] **Feedback visual** — ícone `!` no inimigo; overlay vermelho no jogador ao ser detectado
- [ ] **Velocidade furtiva** — ~60 px/s silenciosa, ativa com `Ctrl`; sem ruído de passos

**Arquivos:** `scripts/farm_enemy.gd`, `scripts/player.gd`

**Critério de saída:** andar devagar = passa pelo Goatman; correr = detectado.

---

## Fase 2 — Darkwatcher #1 + Sistema de Missões

> O jogo tem uma razão para o jogador querer sair da fazenda.

- [ ] **Darkwatcher NPC** — homem de terno, aparece perto da fazenda no dia 2+
  - Diálogo: contextualiza a região, entrega missão inicial
  - Separado do Caim (Caim = tutorial mecânico; Darkwatcher = narrativa/objetivo)
- [ ] **Sistema de missões** — flags booleanas: `mission_1_complete`, `mission_2_complete` etc.
- [ ] **Missão 1** — coletar item em ponto específico (ainda na fazenda ou borda)
- [ ] **Barra de progresso de escape** — UI discreta "X/Y eventos concluídos"

**Arquivos:** `scripts/world.gd` (seção missões), nova cena NPC Darkwatcher

**Critério de saída:** jogador recebe missão, completa, e recebe hint sobre a Floresta de Carne.

---

## Fase 3 — Floresta de Carne

> Primeira área explorável fora da fazenda. Risco real durante o dia.

- [ ] **Tilemap/área da Floresta** — conectada à fazenda por passagem; ambiente escuro
- [ ] **Goatman diurno** — versão mais lenta (patrol 110 px/s, chase 140 px/s), aparece esporadicamente
- [ ] **Recursos valiosos** — madeira especial, minérios (placeholder), carne (placeholder)
- [ ] **Missão 2 do Darkwatcher** — requer item encontrado na Floresta
- [ ] **Sinalização de perigo** — ambiência/música muda ao entrar na área

**Arquivos:** nova cena + tilemap, `scripts/world.gd` (spawn logic por área), `scripts/farm_enemy.gd`

**Critério de saída:** entrar, coletar recurso e sair; Goatman pode aparecer de dia.

---

## Fase 4 — Planícies + Skinwalker

> Segunda área externa. Inimigo novo que exige abordagem diferente do stealth.

- [ ] **Tilemap das Planícies** — área aberta, pouca cobertura
- [ ] **Skinwalker** — se disfarça de animal; ao ver jogador: `IDLE (disfarçado) → REVEAL → CHASE`
  - Responde a **distância**, não a som — diferente do Goatman
- [ ] **Animais (recursos)** — coelhos/veados; matar → carne (comida ou composto)
- [ ] **Missão 3 do Darkwatcher** — passa pela Planície

**Arquivos:** nova cena + tilemap, novo `scripts/skinwalker.gd`

**Critério de saída:** Skinwalker funcional com disfarce; jogador percebe que regra é diferente do Goatman.

---

## Fase 5 — Correnteza + Escape

> Última área. Narrativa se fecha; escape se torna possível.

- [ ] **Tilemap da Correnteza** — água, caminho estreito, tensão de stealth alta
- [ ] **Vendedor na Correnteza** — inventário expandido (pistola, componentes de escape)
- [ ] **Skinwalker raro** — aparece esporadicamente
- [ ] **Darkwatcher final** — explica o que aconteceu; entrega última missão
- [ ] **Condição de escape** — ex: 4 missões concluídas + item comprado no Vendedor
- [ ] **Tela final** — sequência de escape + créditos/texto narrativo

**Critério de saída:** jogador consegue atingir o escape e ver o fim do jogo.

---

## Fase 6 — Sistemas Pendentes

> Enriquecem o loop sem ser o foco principal.

- [ ] **Chuva** — evento que reduz spawn de inimigos; janela segura para explorar/colher
- [ ] **Sistema de dieta** — só vegetais → penaliza vida total; só carne → penaliza stamina
- [ ] **Composto + composteira** — aceita carne/vegetais; acelera crescimento dos plots
- [ ] **Depreciação de preços** — vender mesma colheita repetidamente reduz valor em X%
- [ ] **50% de chance de semente extra** por colheita
- [ ] **Estoque de colheita na cabana** — inventário persistente de colheitas

---

## Fase 7 — Combate

> Altamente desencorajado — existe como última opção desesperada.

- [ ] **Pistola** — no inventário inicial sem bala
- [ ] **Munição** — vendida pelo Vendedor (cara)
- [ ] **Hit/knockback** — inimigo foge ao ser atingido, não morre permanentemente
- [ ] **Ruído de tiro** — atrai outros inimigos próximos
- [ ] **Revólver e Shotgun** — upgrades vendidos (mais dano, mais ruído)

---

## Fase 8 — Polish Final

- [ ] Spritesheets: Darkwatcher, Wendigo, Mimic, Skinwalker
- [ ] Sistema de som por área (ambiência, Foley de passos)
- [ ] Partículas: água, colheita, fogo
- [ ] Tela de título e Game Over com contexto narrativo
- [ ] Balance final baseado em playtest completo do arco inteiro
- [ ] Wendigo e Mimic (inimigos restantes do design document)

---

## Perigos por área (referência rápida)

| Área | Dia | Noite |
|---|---|---|
| Fazenda | Segura (com gerador ligado) | Goatman se gerador apagar |
| Floresta de Carne | Goatman lento (incomum) | Goatman normal |
| Planícies | Skinwalker (comum), animais | Skinwalker + inimigos extras |
| Correnteza | Skinwalker (raro) | Skinwalker (raro) |

---

## O que NÃO fazer antes da hora

- Não implementar Wendigo/Mimic antes do stealth funcionar
- Não adicionar áreas antes da narrativa ter estrutura mínima (missões)
- Não focar em arte final antes de mecânicas validadas
- Não dividir `world.gd` antes de biomas existirem
