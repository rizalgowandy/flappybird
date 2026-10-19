extends Node2D

## Game controller and state machine: HOME -> PLAYING -> GAME_OVER (-> READY).
## Owns input, pipe spawning, scoring, and the HUD. Pauses the tree on game over
## so pipes/ground freeze while the bird keeps falling (bird is PROCESS_MODE_ALWAYS).

enum State { HOME, READY, PLAYING, GAME_OVER }

const BIRD_START := Vector2(140.0, 320.0)
const PIPE_SPEED := 165.0
const SPAWN_INTERVAL := 1.55
const GAP_SIZE := 175.0
const GAP_MIN := 150.0
const GAP_MAX := 470.0
const MAX_GAP_DELTA := 150.0   # cap the vertical jump between consecutive gaps
const SPAWN_X := 520.0
const SAVE_PATH := "user://flappy.cfg"

const PIPE_SCENE := preload("res://scenes/pipe.tscn")

@onready var _bird: Bird = $Playfield/Bird
@onready var _pipes: Node2D = $Playfield/Pipes
@onready var _hud_score: Label = $HUD/Score
@onready var _hud_ready: Control = $HUD/Ready
@onready var _hud_gameover: Control = $HUD/GameOver
@onready var _hud_final: Label = $HUD/GameOver/Panel/VBox/Final
@onready var _hud_best: Label = $HUD/GameOver/Panel/VBox/Best
@onready var _hud_home: Control = $HUD/Home
@onready var _hud_home_title: Label = $HUD/Home/Title
@onready var _hud_home_prompt: Label = $HUD/Home/Prompt

var _state := State.HOME
var _transitioning := false
var _home_title_tween: Tween
var _blink_tween: Tween
var _score := 0
var _best := 0
var _spawn_timer := 0.0
var _last_gap_center := 0.0
var _has_last_gap := false

func _ready() -> void:
	_setup_input()
	_best = _load_best()
	_bird.died.connect(_on_bird_died)
	_hud_score.text = "0"
	get_tree().paused = false
	_enter_home()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("flap"):
		_on_tap()
		get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		is_full = true
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_full:
		target = DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(target)

func _physics_process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_pipe()
		_spawn_timer = SPAWN_INTERVAL

func _on_tap() -> void:
	match _state:
		State.HOME:
			_begin_play()
		State.READY:
			_start_game()
		State.PLAYING:
			_bird.flap()
		State.GAME_OVER:
			_enter_ready()

func _start_game() -> void:
	_stop_home_idle()
	_hud_home.hide()
	_hud_ready.hide()
	_hud_score.show()
	_transitioning = false
	_state = State.PLAYING
	_bird.start()
	_bird.flap()
	_spawn_pipe()
	_spawn_timer = SPAWN_INTERVAL

func _enter_ready() -> void:
	_stop_home_idle()
	_hud_home.hide()
	for pipe in _pipes.get_children():
		pipe.queue_free()
	get_tree().paused = false
	_score = 0
	_hud_score.text = "0"
	_hud_score.hide()
	_hud_gameover.hide()
	_hud_ready.show()
	_state = State.READY
	_has_last_gap = false
	_bird.scale = Vector2.ONE
	_bird.reset(BIRD_START)

func _enter_home() -> void:
	for pipe in _pipes.get_children():
		pipe.queue_free()
	get_tree().paused = false
	_score = 0
	_hud_score.text = "0"
	_hud_score.hide()
	_hud_gameover.hide()
	_hud_ready.hide()
	_hud_home.show()
	_hud_home.modulate.a = 1.0
	_transitioning = false
	_state = State.HOME
	_has_last_gap = false
	_bird.scale = Vector2.ONE
	_bird.reset(BIRD_START)
	_start_home_idle()

## Plays the title -> gameplay entrance animation, then starts the run.
func _begin_play() -> void:
	if _transitioning:
		return
	_transitioning = true
	_stop_home_idle()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_hud_home, "modulate:a", 0.0, 0.35)
	tween.tween_property(_bird, "scale", Vector2.ONE, 0.45) \
		.from(Vector2(0.3, 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_finish_play_transition)

func _finish_play_transition() -> void:
	_hud_home.hide()
	_hud_home.modulate.a = 1.0
	_bird.scale = Vector2.ONE
	_start_game()

func _start_home_idle() -> void:
	_hud_home_title.modulate.a = 1.0
	_hud_home_prompt.modulate.a = 1.0
	_home_title_tween = create_tween().set_loops()
	_home_title_tween.tween_property(_hud_home_title, "modulate:a", 0.7, 1.2)
	_home_title_tween.tween_property(_hud_home_title, "modulate:a", 1.0, 1.2)
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_hud_home_prompt, "modulate:a", 0.35, 0.7)
	_blink_tween.tween_property(_hud_home_prompt, "modulate:a", 1.0, 0.7)

func _stop_home_idle() -> void:
	if _home_title_tween != null and _home_title_tween.is_valid():
		_home_title_tween.kill()
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_hud_home_title.modulate.a = 1.0
	_hud_home_prompt.modulate.a = 1.0

func _spawn_pipe() -> void:
	var pipe := PIPE_SCENE.instantiate() as Pipe
	pipe.speed = PIPE_SPEED
	pipe.gap_size = GAP_SIZE
	var center := _next_gap_center()
	pipe.gap_center = center
	_last_gap_center = center
	_has_last_gap = true
	pipe.position = Vector2(SPAWN_X, 0.0)
	pipe.scored.connect(_on_pipe_scored)
	_pipes.add_child(pipe)

## Picks the next gap centre, keeping it within MAX_GAP_DELTA of the previous one
## so the bird always has a reachable path.
func _next_gap_center() -> float:
	if not _has_last_gap:
		return randf_range(GAP_MIN, GAP_MAX)
	return clampf(
		randf_range(GAP_MIN, GAP_MAX),
		maxf(GAP_MIN, _last_gap_center - MAX_GAP_DELTA),
		minf(GAP_MAX, _last_gap_center + MAX_GAP_DELTA))

func _on_pipe_scored() -> void:
	if _state != State.PLAYING:
		return
	_score += 1
	_hud_score.text = str(_score)

func _on_bird_died() -> void:
	if _state != State.PLAYING:
		return
	_state = State.GAME_OVER
	get_tree().paused = true
	_show_game_over()

func _show_game_over() -> void:
	if _score > _best:
		_best = _score
		_save_best(_best)
	_hud_final.text = "SCORE  %d" % _score
	_hud_best.text = "BEST  %d" % _best
	_hud_gameover.show()

func _setup_input() -> void:
	if not InputMap.has_action("flap"):
		InputMap.add_action("flap")
		for key: Key in [KEY_SPACE, KEY_UP, KEY_W, KEY_ENTER, KEY_KP_ENTER]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event("flap", ev)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("flap", mb)

	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
		var f11 := InputEventKey.new()
		f11.physical_keycode = KEY_F11
		InputMap.action_add_event("toggle_fullscreen", f11)

func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("game", "best", 0))

func _save_best(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", value)
	cfg.save(SAVE_PATH)

# Public API — used by the headless autoplay test (test/autoplay.gd).

func is_playing() -> bool:
	return _state == State.PLAYING

func get_score() -> int:
	return _score

func get_pipes() -> Node2D:
	return _pipes

func get_bird() -> Bird:
	return _bird

func start_run() -> void:
	_start_game()

func restart_run() -> void:
	_enter_ready()
	_start_game()
