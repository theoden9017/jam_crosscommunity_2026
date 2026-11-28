class_name WaveData
extends Resource

## Una riga della tabella delle ondate.

## Quanti lavoratori di ogni tipo compongono l'ondata (tipo -> numero).
## Per aggiungere un tipo basta trascinare il suo .tres come chiave.
@export var enemies: Dictionary[EnemyStats, int] = {}

## Secondi di attesa prima che l'ondata inizi (tempo per costruire).
@export_range(0.0, 120.0, 0.5, "suffix:s") var pause_before: float = 5.0

## Secondi tra un lavoratore e il successivo. 0 = tutti insieme.
@export_range(0.0, 5.0, 0.05, "suffix:s") var spawn_interval: float = 0.25

## Se attivo, la pausa dell'ondata successiva parte solo quando il campo è vuoto.
@export var wait_for_clear: bool = false


func get_enemy_count() -> int:
	var total := 0
	for count in enemies.values():
		total += count
	return total


# Lista piatta dei tipi da far comparire, mescolata.
func build_spawn_list() -> Array[EnemyStats]:
	var list: Array[EnemyStats] = []
	for enemy_stats in enemies:
		if enemy_stats == null:
			continue
		for _i in range(maxi(0, enemies[enemy_stats])):
			list.append(enemy_stats)
	list.shuffle()
	return list
