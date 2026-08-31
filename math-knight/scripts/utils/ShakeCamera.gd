extends Camera2D
class_name ShakeCamera

var max_offset: Vector2 = Vector2(10.0, 8.0)
var max_roll: float = 0.03
var trauma_decay: float = 1.8
var noise: FastNoiseLite

var _trauma: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	EventBus.screen_shake_requested.connect(add_trauma)

func add_trauma(amount: float) -> void:
	_trauma = min(_trauma + amount, 1.0)

func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = max(_trauma - trauma_decay * delta, 0.0)
		_time += delta * 50.0
		var shake: float = _trauma * _trauma
		
		offset.x = max_offset.x * shake * noise.get_noise_2d(noise.seed, _time)
		offset.y = max_offset.y * shake * noise.get_noise_2d(noise.seed + 1, _time)
		rotation = max_roll * shake * noise.get_noise_2d(noise.seed + 2, _time)
	else:
		offset = Vector2.ZERO
		rotation = 0.0
