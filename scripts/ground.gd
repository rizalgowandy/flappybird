extends StaticBody2D

## Scrolling ground. Pausable, so it stops automatically when the tree is paused
## on game over. The region repeats the texture horizontally to fake endless motion.

@export var speed := 165.0
@export var tile_width := 48.0

@onready var _sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	_sprite.region_rect.position.x = fmod(_sprite.region_rect.position.x + speed * delta, tile_width)
