# Asset Manager — carrega e cacheia texturas e animações sprite
# Centraliza paths para assets de spritesheet e tilesets

extends Node

# Cache de texturas carregadas
var _texture_cache: Dictionary = {}
var _spriteframes_cache: Dictionary = {}
var _tileset_cache: Dictionary = {}

# Definições de assets
const ASSET_PATHS = {
	# Player
	"player_blond_kid": "res://assets/Characters/Top-Down-16-bit-fantasy/Characters pack 1/Blond_kid/aseprite.png",

	# Enemies
	"werewolf_idle": "res://assets/Characters/WereWolf/Sprites/Idle/werewolf-idle1.png",
	"werewolf_walk": "res://assets/Characters/WereWolf/Sprites/Walk/",
	"werewolf_run": "res://assets/Characters/WereWolf/Sprites/Run/",

	# Environments
	"haunted_forest_tileset": "res://assets/Environments/HauntedForest/Layers/back-tileset.png",
	"haunted_forest_bg": "res://assets/Environments/HauntedForest/Layers/back.png",
	"haunted_forest_mid": "res://assets/Environments/HauntedForest/Layers/middle.png",

	# NPCs
	"vendor": "res://assets/Characters/Top-Down-16-bit-fantasy/Characters pack 1/Guy/aseprite.png",

	# Misc/Effects
	"explosion": "res://assets/Misc/Explosions pack/",
	"water_splash": "res://assets/Misc/Water splash/",
}

func _ready() -> void:
	pass

## Carrega uma textura pelo ID e cacheia
func load_texture(asset_id: String) -> Texture2D:
	if asset_id in _texture_cache:
		return _texture_cache[asset_id]

	if asset_id not in ASSET_PATHS:
		push_error("Asset não encontrado: ", asset_id)
		return null

	var path = ASSET_PATHS[asset_id]
	var texture = load(path)
	if texture:
		_texture_cache[asset_id] = texture

	return texture

## Carrega uma textura bruta (sem cache)
func load_texture_direct(path: String) -> Texture2D:
	return load(path)

## Obtém um caminho de asset
func get_asset_path(asset_id: String) -> String:
	if asset_id in ASSET_PATHS:
		return ASSET_PATHS[asset_id]
	return ""

## Cria um SpriteFrames para AnimatedSprite2D (geralmente via editor)
func create_spriteframes_from_sheet(texture: Texture2D, frame_width: int, frame_height: int, fps: int = 8) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", fps)

	# Calcula número de frames baseado na textura
	var cols = int(texture.get_width() / frame_width)
	var rows = int(texture.get_height() / frame_height)
	var total_frames = cols * rows

	for i in range(total_frames):
		var col = i % cols
		var row = i / cols
		var atlas_rect = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
		var frame = AtlasTexture.new()
		frame.atlas = texture
		frame.region = atlas_rect
		frames.add_frame("default", frame)

	return frames

## Limpa cache
func clear_cache() -> void:
	_texture_cache.clear()
	_spriteframes_cache.clear()
	_tileset_cache.clear()
