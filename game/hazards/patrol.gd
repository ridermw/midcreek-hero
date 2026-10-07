extends RefCounted
## Horizontal patrol shared by drones and cable piles.
##
##   min_x <-------- origin --------> max_x
##          reverse      start: right   reverse
## step() moves at constant speed and reverses at either bound.
## reset() returns to the authored origin and direction.

var origin: float
var min_x: float
var max_x: float
var speed: float
var direction: float = 1.0
var x: float


func _init(start: float, left: float, right: float, pixels_per_second: float) -> void:
	origin = start
	min_x = left
	max_x = right
	speed = pixels_per_second
	x = start


func step(delta: float) -> float:
	x += direction * speed * delta
	if x >= max_x:
		x = max_x
		direction = -1.0
	elif x <= min_x:
		x = min_x
		direction = 1.0
	return x


func reset() -> void:
	x = origin
	direction = 1.0
