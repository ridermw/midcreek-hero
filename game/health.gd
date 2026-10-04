extends RefCounted

signal changed(segments: int)
signal died

const MAX_SEGMENTS := 5
const INVULNERABLE_SECONDS := 1.0

var segments: int = MAX_SEGMENTS
var hits_taken: int = 0
var _invulnerable_remaining: float = 0.0


func damage() -> bool:
	if segments == 0 or _invulnerable_remaining > 0.0:
		return false
	segments -= 1
	hits_taken += 1
	_invulnerable_remaining = INVULNERABLE_SECONDS
	changed.emit(segments)
	if segments == 0:
		died.emit()
	return true


func heal() -> void:
	if segments == 0 or segments == MAX_SEGMENTS:
		return
	segments += 1
	changed.emit(segments)


func tick(delta: float) -> void:
	_invulnerable_remaining = maxf(_invulnerable_remaining - delta, 0.0)


func is_invulnerable() -> bool:
	return _invulnerable_remaining > 0.0


func refill() -> void:
	segments = MAX_SEGMENTS
	_invulnerable_remaining = 0.0
	changed.emit(segments)
