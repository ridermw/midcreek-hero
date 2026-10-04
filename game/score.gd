extends RefCounted


static func stars(elapsed: float, par: float, hits: int) -> int:
	if elapsed >= par:
		return 1
	return 3 if hits <= 1 else 2
