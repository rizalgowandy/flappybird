extends StaticBody2D
class_name Pipe

## A pipe pair (top + bottom) with a score zone across the gap.
## The spawner sets `speed`, `gap_size`, and `gap_center` before adding it to the tree;
## `_build()` lays out the sprites, collision shapes, and score area from those values.

signal scored

const BODY_W := 76.0
const CAP_W := 84.0
const CAP_H := 40.0
const PLAYFIELD_H := 640.0

@export var speed := 165.0
@export var gap_size := 175.0
var gap_center := 300.0

var _scored := false

@onready var _top_body: Sprite2D = $TopBody
@onready var _top_cap: Sprite2D = $TopCap
@onready var _top_shape: CollisionShape2D = $TopShape
@onready var _bottom_body: Sprite2D = $BottomBody
@onready var _bottom_cap: Sprite2D = $BottomCap
@onready var _bottom_shape: CollisionShape2D = $BottomShape
@onready var _score_zone: Area2D = $ScoreZone
@onready var _score_shape: CollisionShape2D = $ScoreZone/ScoreShape

func _ready() -> void:
	_build()
	_score_zone.area_entered.connect(_on_score_area)

func _build() -> void:
	var gap_top := gap_center - gap_size * 0.5
	var gap_bottom := gap_center + gap_size * 0.5
	var bottom_h := maxf(PLAYFIELD_H - gap_bottom, 1.0)

	# Top pipe runs from the top of the playfield down to the gap.
	_top_body.position = Vector2.ZERO
	_top_body.region_rect = Rect2(0.0, 0.0, BODY_W, maxf(gap_top, 1.0))
	_top_cap.position = Vector2((BODY_W - CAP_W) * 0.5, gap_top - CAP_H)
	_top_shape.position = Vector2(BODY_W * 0.5, gap_top * 0.5)
	_top_shape.shape = _rect_shape(Vector2(BODY_W, maxf(gap_top, 1.0)))

	# Bottom pipe runs from the gap down to the playfield floor.
	_bottom_body.position = Vector2(0.0, gap_bottom)
	_bottom_body.region_rect = Rect2(0.0, 0.0, BODY_W, bottom_h)
	_bottom_cap.position = Vector2((BODY_W - CAP_W) * 0.5, gap_bottom)
	_bottom_shape.position = Vector2(BODY_W * 0.5, gap_bottom + bottom_h * 0.5)
	_bottom_shape.shape = _rect_shape(Vector2(BODY_W, bottom_h))

	# Score zone spans the gap; the bird enters it as it passes the pipe.
	_score_shape.position = Vector2(BODY_W * 0.5, gap_center)
	_score_shape.shape = _rect_shape(Vector2(BODY_W, gap_size))

## Builds a fresh RectangleShape2D. Scene sub-resources are shared between all
## Pipe instances, so resizing the scene's shape in place would corrupt every
## other live pipe's collision; each pipe needs its own shape.
func _rect_shape(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape

func _physics_process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -CAP_W:
		queue_free()

func _on_score_area(_area: Area2D) -> void:
	if _scored:
		return
	_scored = true
	scored.emit()
