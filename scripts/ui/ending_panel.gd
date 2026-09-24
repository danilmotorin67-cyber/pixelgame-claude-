class_name EndingPanel

# Phase 3 of the Great Tide (5.6): Rann shows every ending; closed ones are marked, with what was missing.


static func reasons(ending: String) -> Array:
	var miss := Finale.missing(ending)
	if Finale.forced_postpone() and ending != "D" and not miss.has("gills"):
		miss.append("gills")
	var out: Array = []
	for m in miss:
		out.append(Loc.t("ending.missing." + str(m)))
	return out


static func line(ending: String) -> String:
	var why := reasons(ending)
	return "%s %s%s" % ["○" if why.is_empty() else "×", Loc.t("ending.%s.title" % ending.to_lower()),
		(" — " + "; ".join(why)) if not why.is_empty() else ""]


static func open(hud: CanvasLayer) -> InfoPanel:
	var body := func() -> String:
		return Loc.t("ending.head") + "\n" + Loc.t("ending.warn_c")
	var lines := func() -> Array:
		var out: Array = []
		for e in Finale.ENDINGS:
			out.append(line(str(e)))
		return out
	var about := func(p: InfoPanel) -> String:
		var index := p.selected_index()
		if index < 0:
			return ""
		return Loc.t("ending.%s.desc" % str(Finale.ENDINGS[index]).to_lower())
	var choose := func(p: InfoPanel) -> String:
		var index := p.selected_index()
		if index < 0:
			return ""
		var ending := str(Finale.ENDINGS[index])
		if not Finale.choose(ending):
			return Loc.t("ending.closed") % "; ".join(reasons(ending))
		p.close()
		if ending != "D":
			CourtPanel.open(hud)
		else:
			InfoPanel.open(hud, Loc.t("ending.d.title"), func() -> String: return Story.page_text(24))
		return Loc.t("ending.chosen")
	return InfoPanel.open(hud, Loc.t("q.q4_5_great_tide.halls"), body, [["Подробнее", about], ["Выбрать", choose]], lines)
