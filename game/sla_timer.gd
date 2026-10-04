extends RefCounted

signal warning
signal expired

const WARNING_SECONDS := 30.0
const RESTART_MINIMUM_SECONDS := 30.0

var remaining: float = 0.0
var elapsed: float = 0.0
var running: bool = false
var _warned: bool = false


func start(seconds: float) -> void:
	remaining = seconds
	elapsed = 0.0
	running = true
	_warned = remaining <= WARNING_SECONDS


func stop() -> void:
	running = false


func tick(delta: float) -> void:
	if not running:
		return
	var step := minf(delta, remaining)
	remaining -= step
	elapsed += step
	if not _warned and remaining <= WARNING_SECONDS:
		_warned = true
		warning.emit()
	if remaining <= 0.0:
		remaining = 0.0
		running = false
		expired.emit()


func restore(value: float) -> void:
	remaining = maxf(value, RESTART_MINIMUM_SECONDS)
	running = true
	_warned = remaining <= WARNING_SECONDS
