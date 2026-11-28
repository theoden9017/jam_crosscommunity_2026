class_name WaveTable
extends Resource

## Progressione delle ondate di un livello: una WaveData per ondata, in ordine.
## Si modifica dall'Inspector aprendo il .tres; per un nuovo livello basta duplicarlo.

@export var waves: Array[WaveData] = []


func size() -> int:
	return waves.size()


func get_wave(index: int) -> WaveData:
	if index < 0 or index >= waves.size():
		return null
	return waves[index]
