# Script para gerar SpriteFrames corretamente
# Rode este script uma vez no editor (_ready) e depois delete

extends Node

func _ready() -> void:
	# Gerar SpriteFrames para player
	_create_player_spriteframes()
	# Gerar SpriteFrames para werewolf
	_create_werewolf_spriteframes()


func _create_player_spriteframes() -> void:
	var spritesheet_path = "res://assets/Characters/Top-Down-16-bit-fantasy/Characters pack 1/Blond_kid/aseprite.png"
	var texture = load(spritesheet_path) as Texture2D

	if not texture:
		push_error("Não conseguiu carregar: ", spritesheet_path)
		return

	print("Player spritesheet size: ", texture.get_size())

	var frames = SpriteFrames.new()

	# Detectar tamanho baseado na textura carregada
	var img_width = texture.get_width()
	var img_height = texture.get_height()

	# Assumir layout: 4 colunas x 4 linhas = 16 frames
	var frame_width = img_width / 4
	var frame_height = img_height / 4

	print("Dimensões calculadas: %dx%d por frame" % [frame_width, frame_height])

	# Criar animações
	var animations = {
		"idle": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"walk": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		"run": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],
		"exhausted": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)],
	}

	for anim_name in animations.keys():
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)

		for grid_pos in animations[anim_name]:
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = Rect2(
				grid_pos.x * frame_width,
				grid_pos.y * frame_height,
				frame_width,
				frame_height
			)
			frames.add_frame(anim_name, atlas_tex)

	ResourceSaver.save(frames, "res://assets/spriteframes/player_blond_kid.tres")
	print("✅ player_blond_kid.tres salvo!")


func _create_werewolf_spriteframes() -> void:
	var frames = SpriteFrames.new()

	# Idle (5 frames)
	var idle_frames = [
		"res://assets/Characters/WereWolf/Sprites/Idle/werewolf-idle1.png",
		"res://assets/Characters/WereWolf/Sprites/Idle/werewolf-idle2.png",
		"res://assets/Characters/WereWolf/Sprites/Idle/werewolf-idle3.png",
		"res://assets/Characters/WereWolf/Sprites/Idle/werewolf-idle4.png",
		"res://assets/Characters/WereWolf/Sprites/Idle/werewolf-idle5.png",
	]

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 6.0)
	for path in idle_frames:
		var tex = load(path) as Texture2D
		if tex:
			frames.add_frame("idle", tex)

	# Run (6 frames)
	var run_frames = [
		"res://assets/Characters/WereWolf/Sprites/run/werewolf-run1.png",
		"res://assets/Characters/WereWolf/Sprites/run/werewolf-run2.png",
		"res://assets/Characters/WereWolf/Sprites/run/werewolf-run3.png",
		"res://assets/Characters/WereWolf/Sprites/run/werewolf-run4.png",
		"res://assets/Characters/WereWolf/Sprites/run/werewolf-run5.png",
		"res://assets/Characters/WereWolf/Sprites/run/werewolf-run6.png",
	]

	frames.add_animation("run")
	frames.set_animation_speed("run", 10.0)
	for path in run_frames:
		var tex = load(path) as Texture2D
		if tex:
			frames.add_frame("run", tex)

	# Fall (2 frames)
	var fall_frames = [
		"res://assets/Characters/WereWolf/Sprites/fall/werewolf-fall1.png",
		"res://assets/Characters/WereWolf/Sprites/fall/werewolf-fall2.png",
	]

	frames.add_animation("fall")
	frames.set_animation_speed("fall", 5.0)
	for path in fall_frames:
		var tex = load(path) as Texture2D
		if tex:
			frames.add_frame("fall", tex)

	ResourceSaver.save(frames, "res://assets/spriteframes/enemy_werewolf.tres")
	print("✅ enemy_werewolf.tres salvo!")
