class_name EndingPanel

# Phase 3 of the Great Tide (5.6): Rann shows every ending; closed ones are grey, with what was missing.


static func text() -> String:
	var lines: Array = [Loc.t("ending.head")]
	for e in Finale.ENDINGS:
		var key := str(e).to_lower()
		var miss := Finale.missing(str(e))
		if Finale.forced_postpone() and e != "D":
			miss.append("gills")
		var reasons: Array = []
		for m in miss:
			reasons.append(Loc.t("ending.missing." + str(m)))
		lines.append("%s %s — %s%s" % ["○" if miss.is_empty() else "×", Loc.t("ending.%s.title" % key), Loc.t("ending.%s.desc" % key),
			("\n   " + Loc.t("ending.closed") % "; ".join(reasons)) if not reasons.is_empty() else ""])
	lines.append(Loc.t("ending.warn_c"))
	return "\n".join(lines)


static func open(hud: CanvasLayer) -> InfoPanel:
	var buttons: Array = []
	for e in Finale.ENDINGS:
		var ending := str(e)
		buttons.append([Loc.t("ending.%s.title" % ending.to_lower()), func(p: InfoPanel) -> String:
			if not Finale.choose(ending):
				return Loc.t("ending.closed") % Loc.t("ending.%s.title" % ending.to_lower())
			p.close()
			if ending != "D":
				CourtPanel.open(hud)
			else:
				InfoPanel.open(hud, Loc.t("ending.d.title"), func() -> String: return Story.page_text(24))
			return Loc.t("ending.chosen")])
	return InfoPanel.open(hud, Loc.t("q.q4_5_great_tide.halls"), func() -> String: return text(), buttons)
