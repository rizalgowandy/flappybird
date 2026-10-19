extends Area2D
class_name Bird

## The player bird: gravity + flap movement, wing animation, tilt, and death.
## Collision is done with an Area2D so the bird dies on contact instead of
## bouncing off pipes/ground (they are StaticBody2D on the "world" layer).

signal died

enum State { READY, PLAYING, DYING, DEAD }

@export var fall_gravity := 1500.0
@export var flap_velocity := -430.0
@export var max_fall_speed := 720.0
@export var tilt_up := -0.5          # radians, nose up while rising
@export var tilt_down := 1.35        # radians, nose down while diving
@export var tilt_speed := 7.0
@export var death_tilt_speed := 12.0

const GROUND_Y := 640.0
const BODY_RADIUS := 13.0
const READY_BOB_AMPLITUDE := 10.0
const READY_BOB_SPEED := 4.0

var _vy := 0.0
var _state := State.READY
var _base_y := 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_sprite.play("flap")
	body_entered.connect(_on_body_entered)

func reset(at: Vector2) -> void:
	global_position = at
	_base_y = at.y
	rotation = 0.0
	_vy = 0.0
	_state = State.READY
	_sprite.play("flap")
	set_physics_process(true)

func start() -> void:
	if _state == State.READY:
		_state = State.PLAYING

func flap() -> void:
	if _state == State.READY:
		_state = State.PLAYING
	if _state == State.PLAYING:
		_vy = flap_velocity
		rotation = tilt_up
		_sprite.play("flap")

func kill() -> void:
	if _state == State.PLAYING or _state == State.READY:
		_state = State.DYING
		_vy = minf(_vy, -160.0)   # small pop upward on impact
		_sprite.stop()

func _physics_process(delta: float) -> void:
	match _state:
		State.READY:
			_bob()
		State.PLAYING:
			_fall(delta)
			_tilt(delta, tilt_speed)
		State.DYING:
			_fall(delta)
			rotation = minf(rotation + death_tilt_speed * delta, PI / 2.0)
			if global_position.y >= GROUND_Y - BODY_RADIUS:
				global_position.y = GROUND_Y - BODY_RADIUS
				_rest()

func _bob() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	rotation = 0.0
	global_position.y = _base_y + sin(t * READY_BOB_SPEED) * READY_BOB_AMPLITUDE

func _fall(delta: float) -> void:
	_vy = minf(_vy + fall_gravity * delta, max_fall_speed)
	global_position.y += _vy * delta
	if _state == State.PLAYING and global_position.y < 0.0:
		global_position.y = 0.0
		_vy = 0.0

func _tilt(delta: float, speed: float) -> void:
	var target := tilt_down
	if _vy < 0.0:
		target = tilt_up
	else:
		target = lerpf(tilt_up, tilt_down, clampf(_vy / max_fall_speed, 0.0, 1.0))
	rotation = lerp_angle(rotation, target, clampf(speed * delta, 0.0, 1.0))

func velocity_y() -> float:
	return _vy

func _rest() -> void:
	_state = State.DEAD
	set_physics_process(false)

func _on_body_entered(_body: Node2D) -> void:
	if _state == State.PLAYING:
		kill()
		died.emit()
