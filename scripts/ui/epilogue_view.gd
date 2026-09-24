class_name EpilogueView

# The epilogue (5.6): six to eight slides of how the story ended, then free play.
static var index: int = 0


static func open(hud: CanvasLayer) -> InfoPanel:
	var slides := Finale.epilogue_slides()
	index = 0
	var body := func() -> String:
		if index >= slides.size():
			return Loc.t("epilogue.free")
		return "%d / %d\n\n%s" % [index + 1, slides.size(), Loc.t(str(slides[index]))]
	Finale.epilogue_shown = true
	return InfoPanel.open(hud, Loc.t("epilogue.title"), body, [[Loc.t("epilogue.next"), func(_p: InfoPanel) -> String:
		index += 1
		return ""]])
