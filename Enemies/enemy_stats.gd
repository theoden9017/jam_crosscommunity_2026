class_name EnemyStats
extends Resource

## Statistiche di un tipo di lavoratore. Crea un nuovo .tres per ogni tipo.

@export var display_name: String = "Lavoratore"

@export_group("Vita")
## Quanta "persuasione" serve per convincerlo a scioperare.
@export var max_health: float = 100.0

@export_group("Movimento")
@export var move_speed: float = 3.0
@export var acceleration: float = 12.0
@export var turn_speed_degrees: float = 240.0

@export_group("Ricompensa")
## Quota sindacale versata nelle casse quando viene convinto.
@export var union_dues: int = 10

@export_group("Aspetto")
## Moltiplica il colore del materiale, per distinguere i tipi a colpo d'occhio.
@export var tint: Color = Color.WHITE
## Moltiplica la scala del modello (solo grafica, non la collisione).
@export var model_scale: float = 1.0

@export_group("Endless")
## Probabilità relativa di comparire nella modalità endless (0 = mai).
@export var endless_weight: float = 1.0
