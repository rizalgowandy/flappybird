extends Node

## Headless autoplay test for the Flappy Bird game.
##
## Drives the REAL game scene (res://scenes/main.tscn) with a simple predictive
## autopilot and stops when the score target is reached or the time budget
## expires. On death it restarts automatically and keeps trying within the
## budget, so a single run reports the best score achievable.
##
## Usage:
##   godot --headless --path . res://test/autoplay.tscn -- --target 30 --minutes 2
##   godot --headless --path . --fixed-fps 60 res://test/autoplay.tscn -- 30 2
##
## Args (both optional, flags or two positionals):
##   --target N    score to reach before passing        (default 30)
##   --minutes M   time budget in (simulated) minutes   (default 2)
##
## Exit codes:
##   0  target reached
##   1  time budget expired without reaching the target
##   2  bad arguments / setup error
##
## Note: run with --fixed-fps 60 to simulate far faster than real time.

const MAIN_SCENE := "res://scenes/main.tscn"
const BODY_W := 76.0
const BODY_R := 13.0

var _target := 30
var _minutes := 2.0

var _main: Node
var _bird: Node
var _pipes: Node

var _elapsed := 0.0
var _attempt := 0
var _best := 0
var _need_restart := false
var _finished := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _parse_args():
		print("[autoplay] ERROR: bad arguments (need --target>0 and --minutes>0)")
		get_tree().quit(2)
		return

	print("[autoplay] target=%d minutes=%.2f" % [_target, _minutes])
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(_main)
	await get_tree().process_frame
	_bird = _main.get_bird()
	_pipes = _main.get_pipes()
	if _bird == null or _pipes == null:
		print("[autoplay] ERROR: could not find game nodes")
		get_tree().quit(2)
		return
	_bird.died.connect(_on_died)
	_attempt = 1
	_main.start_run()

func _parse_args() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0].is_valid_int():
		_target = int(args[0])
	if args.size() >= 2 and args[1].is_valid_float():
		_minutes = float(args[1])
	var i := 0
	while i < args.size():
		if args[i] == "--target" and i + 1 < args.size():
			_target = int(args[i + 1])
			i += 2
			continue
		if args[i] == "--minutes" and i + 1 < args.size():
			_minutes = float(args[i + 1])
			i += 2
			continue
		i += 1
	return _target > 0 and _minutes > 0.0

func _physics_process(delta: float) -> void:
	if _finished:
		return

	if _need_restart:
		_need_restart = false
		_attempt += 1
		_main.restart_run()
		return

	_elapsed += delta
	if _elapsed >= _minutes * 60.0:
		_finish(false)
		return

	if not _main.is_playing():
		return

	if _main.get_score() >= _target:
		_best = maxi(_best, _main.get_score())
		_finish(true)
		return

	_autopilot()

func _autopilot() -> void:
	var bx: float = _bird.global_position.x
	var by: float = _bird.global_position.y
	var target := 320.0
	var nearest_x := INF
	for pipe in _pipes.get_children():
		# Aim at the nearest pipe not yet fully passed, so the bird holds its
		# gap for the whole traversal instead of veering off mid-pipe.
		if pipe.position.x + BODY_W + BODY_R > bx and pipe.position.x < nearest_x:
			nearest_x = pipe.position.x
			target = pipe.gap_center
	# Flap only while falling/at apex and below the target, so the bird does
	# not rocket upward by re-flapping every frame.
	if _bird.velocity_y() >= 0.0 and by > target - 10.0:
		_bird.flap()

func _on_died() -> void:
	if _finished:
		return
	_best = maxi(_best, _main.get_score())
	print("[autoplay] attempt %d died at score %d (best %d)" % [
		_attempt, _main.get_score(), _best])
	_need_restart = true

func _finish(passed: bool) -> void:
	if _finished:
		return
	_finished = true
	if passed:
		print("[autoplay] PASS: reached score %d in attempt %d (%.1fs, best %d)" % [
			_target, _attempt, _elapsed, _best])
		_quit(0)
	else:
		print("[autoplay] FAIL: best score %d after %.1fs / %d attempt(s)" % [
			_best, _elapsed, _attempt])
		_quit(1)

func _quit(code: int) -> void:
	get_tree().paused = false
	get_tree().quit(code)
