class_name Minigame
extends RefCounted

# A short game of skill (24.2, 12.4, 5.4): festivals, the daughters' trials, the break-in and the ambush.
# The model runs without a screen — tick() advances it, press() takes the keeper's input, autoplay() lets a
# bot of the given skill play it through (tests and the "skip" option). MinigameView draws it.
var kind: String = ""
var title: String = ""
var done: bool = false
var won: bool = false
var score: float = 0.0
var time: float = 0.0
var limit: float = 60.0
var rng := RandomNumberGenerator.new()
var params: Dictionary = {}


static func make(type: String, p: Dictionary = {}) -> Minigame:
	var game: Minigame
	match type:
		"timing":
			game = TimingGame.new()
		"mash":
			game = MashGame.new()
		"lanes":
			game = LaneGame.new()
		"race":
			game = RaceGame.new()
		"guess":
			game = GuessGame.new()
		_:
			game = TimingGame.new()
	game.kind = type
	game.params = p
	game.title = str(p.get("title", ""))
	game.limit = float(p.get("limit", game.limit))
	game.rng.seed = int(p.get("seed", 1))
	game.setup(p)
	return game


func setup(_p: Dictionary) -> void:
	pass


func tick(delta: float) -> void:
	if done:
		return
	time += delta
	step(delta)
	if time >= limit and not done:
		finish()


func step(_delta: float) -> void:
	pass


func press(_action: String) -> void:
	pass


func finish() -> void:
	done = true
	won = judge()


func judge() -> bool:
	return score >= float(params.get("need", 1))


# The bot's move this frame; skill 0..1.
func bot(_skill: float) -> void:
	pass


func autoplay(skill: float, max_seconds: float = 900.0) -> Minigame:
	var dt := 1.0 / 30.0
	var t := 0.0
	while not done and t < max_seconds:
		bot(skill)
		tick(dt)
		t += dt
	if not done:
		finish()
	return self


func status() -> String:
	return "%s  %d  %d с" % [title, int(score), maxi(0, int(limit - time))]


func draw(_ci: CanvasItem, _size: Vector2) -> void:
	pass
