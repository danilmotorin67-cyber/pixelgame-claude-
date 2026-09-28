class_name CreditsPanel
extends MenuWindow

# «Авторы»: who made the game and the licences its parts ask to be named under.
const LINES := [
	["«Солёный свет»", "gold"],
	["Игра, сценарий, дизайн — автор проекта", ""],
	["Код и сборка — с помощью Claude Code (Anthropic)", ""],
	["Пиксель-арт — PixelLab; иллюстрации — GPT Image", ""],
	["", ""],
	["Шрифт Tiny5 — Stefan Schmidt, SIL Open Font License 1.1", "muted"],
	["Движок Godot Engine — MIT License, © Juan Linietsky, Ariel Manzur и участники Godot Engine", "muted"],
	["", ""],
	["Спасибо, что зажигаете огонь.", "gold"],
]


func _init() -> void:
	super("Авторы")


func _ready() -> void:
	for line in LINES:
		var color := UiKit.GOLD if line[1] == "gold" else (UiKit.MUTED if line[1] == "muted" else UiKit.PAPER)
		add_label(str(line[0]), color).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	super()
