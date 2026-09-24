class_name KnowledgeBook
extends RefCounted

# The knowledge tree of 26 (six branches) and the skills page of 25, opened at the keeper's desk or with K.
const BRANCHES := ["lighthouse", "graveyard", "land", "sea", "craft", "secret"]
const BRANCH_NAMES := {"lighthouse": "M · Маяк", "graveyard": "P · Погост", "land": "Z · Земля", "sea": "S · Море",
	"craft": "R · Ремесло", "secret": "T · Тайное"}
const MARKS := {"unlocked": "✓", "": "○", "points": "·", "requires": "·", "story": "?"}


static func nodes_of(branch: String) -> Array:
	return Data.all("knowledge_tree").filter(func(n: Dictionary) -> bool: return str(n.get("branch", "")) == branch)


static func cost_text(info: Dictionary) -> String:
	var cost: Array[String] = []
	for kind in info.get("cost", {}):
		if int(info["cost"][kind]) > 0:
			cost.append("%d%s" % [int(info["cost"][kind]), {"sea": "⚓", "land": "🌿", "rest": "🕯"}.get(kind, "")])
	return " ".join(cost) if not cost.is_empty() else "бесплатно"


static func node_lines(branch: String) -> Array:
	var out: Array = []
	for info in nodes_of(branch):
		var state := Knowledge.blocked_reason(str(info["id"]))
		out.append("%s %s %s — %s" % [MARKS.get(state, "·"), info["id"], Loc.t("node.%s.name" % info["id"]), cost_text(info)])
	return out


static func skill_lines() -> Array:
	var out: Array = []
	for skill in Skills.NAMES:
		var lv := Skills.base_level(skill)
		var next := Skills.THRESHOLDS[lv] if lv < 10 else 0
		var profs: Array[String] = []
		for id in Skills.professions.get(skill, []):
			profs.append(Loc.t("profession.%s.name" % id))
		out.append("%s — ур. %d%s%s" % [Loc.t("skill." + skill), lv, (" · опыт %d/%d" % [int(Skills.xp.get(skill, 0)), next]) if lv < 10 else "",
			(" · " + ", ".join(profs)) if not profs.is_empty() else ""])
	return out


static func open(hud: CanvasLayer) -> InfoPanel:
	var state := {"branch": 0, "skills": false}
	var body := func() -> String:
		var head := "Записи: ⚓ %d · 🌿 %d · 🕯 %d." % [Knowledge.sea_pts, Knowledge.land_pts, Knowledge.rest_pts]
		if bool(state["skills"]):
			return head + " Навыки и профессии (25):"
		return head + " Ветвь: %s. ✓ открыт, ○ можно открыть, ? ждёт сюжета." % BRANCH_NAMES[BRANCHES[int(state["branch"])]]
	var rows := func() -> Array:
		return skill_lines() if bool(state["skills"]) else node_lines(BRANCHES[int(state["branch"])])
	var prev := func(panel: InfoPanel) -> String:
		state["skills"] = false
		state["branch"] = posmod(int(state["branch"]) - 1, BRANCHES.size())
		panel.refresh()
		return ""
	var next := func(panel: InfoPanel) -> String:
		state["skills"] = false
		state["branch"] = posmod(int(state["branch"]) + 1, BRANCHES.size())
		panel.refresh()
		return ""
	var unlock := func(panel: InfoPanel) -> String:
		if bool(state["skills"]):
			return "Это страница навыков."
		var list := nodes_of(BRANCHES[int(state["branch"])])
		var index := panel.selected_index()
		if index < 0 or index >= list.size():
			return "Выберите узел."
		var id := str(list[index]["id"])
		var reason := Knowledge.blocked_reason(id)
		if Knowledge.unlock_node(id):
			return "Узел %s открыт: %s." % [id, Loc.t("node.%s.name" % id)]
		return {"unlocked": "Уже открыт.", "requires": "Сначала предыдущие узлы.", "story": "Ждёт событий сюжета.",
			"points": "Не хватает записей."}.get(reason, "Нельзя.")
	var skills := func(panel: InfoPanel) -> String:
		state["skills"] = not bool(state["skills"])
		panel.refresh()
		return ""
	return InfoPanel.open(hud, "Древо знаний", body, [["◀", prev], ["▶", next], ["Открыть узел", unlock], ["Навыки", skills]], rows)


# Level 5 and 10 (25.1): one of two professions; the offer repeats until the keeper picks.
static func offer_profession(hud: CanvasLayer) -> InfoPanel:
	if Skills.pending.is_empty():
		return null
	var entry: Dictionary = Skills.pending[0]
	var skill := str(entry["skill"])
	var options := Skills.options(skill, int(entry["level"]))
	var body := func() -> String:
		return "%s: уровень %d. Выберите профессию (сбросить можно только у Колодца забвения)." % [Loc.t("skill." + skill), int(entry["level"])]
	var rows := func() -> Array:
		var out: Array = []
		for id in options:
			out.append("%s — %s" % [Loc.t("profession.%s.name" % id), Loc.t("profession.%s.desc" % id)])
		return out
	var pick := func(panel: InfoPanel) -> String:
		var index := panel.selected_index()
		if index < 0 or index >= options.size():
			return "Выберите профессию."
		Skills.choose(skill, str(options[index]))
		panel.name = "InfoPanelDone"
		panel.close()
		(func() -> void: KnowledgeBook.offer_profession(hud)).call_deferred()
		return ""
	return InfoPanel.open(hud, "Вы стали опытнее", body, [["Выбрать", pick]], rows)
