# 🔧 CORRIGINDO SPRITES — Guia Rápido

## Problema
Os SpriteFrames `.tres` foram criados com configuração incorreta. Os spritesheets **não estão aparecendo** no jogo.

## Solução
Use o script `scripts/sprite_generator.gd` para **gerar os SpriteFrames corretamente** baseado nas dimensões reais dos spritesheets.

---

## Passo a Passo

### 1. Abra Godot Editor
- Abra o projeto em `C:\Users\Made by Felipe\Documents\Fleshwoods`

### 2. Crie uma cena temporária
- Nova Scene → Node2D
- Salve como `debug_sprites.tscn`

### 3. Adicione o script gerador
- Adicione um Node ao scene root
- Attach `res://scripts/sprite_generator.gd`

### 4. Rode a cena (F5)
- O script vai:
  1. Carregar os spritesheets
  2. Calcular frame size automaticamente
  3. Gerar `player_blond_kid.tres` com configuração correta
  4. Gerar `enemy_werewolf.tres` com configuração correta
  5. Imprimir `✅ arquivo.tres salvo!`

### 5. Verifique Output
- Abra Console (View → Output)
- Deve ver:
  ```
  Player spritesheet size: (128, 128)
  Dimensões calculadas: 32x32 por frame
  ✅ player_blond_kid.tres salvo!
  ✅ enemy_werewolf.tres salvo!
  ```

### 6. Delete scene de teste
- Delete `debug_sprites.tscn`
- Delete `scripts/sprite_generator.gd` (opcional — script foi só para gerar)

### 7. Reloaded scenes
- Feche e abra novamente `scenes/player.tscn`
- Feche e abra novamente `scenes/farm_enemy.tscn`
- Verifique que agora os sprites aparecem corretamente

### 8. Rode o jogo (F5)
- Launch `scenes/world.tscn`
- Player deve aparecer como **Blond_kid sprite** (não mais retângulo)
- Mova com WASD → animações devem trocar (idle → walk → run)
- Noite → Goatman aparece como **WereWolf sprite** (não mais círculo preto)

---

## Se ainda não funcionar

### A. Verificar UIDs
Edite `scenes/player.tscn` em texto:
```
[ext_resource type="Resource" path="res://assets/spriteframes/player_blond_kid.tres" id="3_player_frames"]
```

Remova qualquer `uid=` - deixe apenas `path=`.

### B. Reimportar assets
- Delete `assets/.godot/` (cache Godot)
- Delete `assets/spriteframes/*.import`
- Reimporte tudo (Project → Rescan Filesystem)

### C. Verificar paths
```gdscript
# Em player.gd, teste:
print(load("res://assets/spriteframes/player_blond_kid.tres"))
```

Se retornar null → path está errado.

---

## Estrutura esperada após fix

```
assets/
├── spriteframes/
│   ├── player_blond_kid.tres (GERADO — 4 animations, 16 frames total)
│   └── enemy_werewolf.tres (GERADO — 3 animations, 13 frames total)
├── Characters/
│   ├── Top-Down-16-bit-fantasy/
│   │   └── Characters pack 1/Blond_kid/aseprite.png ✅
│   └── WereWolf/
│       └── Sprites/
│           ├── Idle/ (5 PNGs) ✅
│           ├── run/ (6 PNGs) ✅
│           └── fall/ (2 PNGs) ✅
```

---

## Checklist Final

- [ ] `sprite_generator.gd` rodou com sucesso
- [ ] `player_blond_kid.tres` e `enemy_werewolf.tres` regenerados
- [ ] `scenes/player.tscn` aberto → sprite visible no editor
- [ ] `scenes/farm_enemy.tscn` aberto → sprite visible no editor
- [ ] Game rodado → Player como Blond_kid
- [ ] Game rodado → Goatman como WereWolf à noite
- [ ] Animações funcionam (WASD muda idle → walk)
- [ ] FPS está 60+

---

## Próximo Passo
Após sprites funcionarem, delete `scripts/sprite_generator.gd` e `FIX_SPRITES.md`, então continue com Phase 5 testes.
