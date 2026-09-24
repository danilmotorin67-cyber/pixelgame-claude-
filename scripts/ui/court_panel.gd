class_name CourtPanel

# The morning after (Q4.6): the villains' fate (pardon only with Ingrid 8+ and Honour 30+), Fortuna's choice,
# then the epilogue slides.


static func open(hud: CanvasLayer) -> InfoPanel:
	var body := func() -> String:
		return Story.page_text(24) + ("\n\n" + Loc.t("court.%s" % Story.resolution) if Finale.court_done else "")
	var buttons: Array = []
	if not Finale.court_done:
		buttons.append(["Суд", func(_p: InfoPanel) -> String: return Loc.t("court.%s" % Finale.judge(false))])
		if Finale.can_pardon():
			buttons.append(["Помилование", func(_p: InfoPanel) -> String: return Loc.t("court.%s" % Finale.judge(true))])
	if Finale.fortuna_can_choose():
		buttons.append(["Фортуна: остаться", func(_p: InfoPanel) -> String:
			return Loc.t("fortuna.stay") if Finale.fortuna(false) == "stays" else Loc.t("fortuna.rest")])
		buttons.append(["Фортуна: отпустить", func(_p: InfoPanel) -> String:
			Finale.fortuna(true)
			return Loc.t("fortuna.release")])
	buttons.append([Loc.t("epilogue.title"), func(p: InfoPanel) -> String:
		if not Finale.court_done:
			Finale.judge(false)
		p.close()
		EpilogueView.open(hud)
		return ""])
	return InfoPanel.open(hud, Loc.t("q.q4_6_court.title"), body, buttons)
