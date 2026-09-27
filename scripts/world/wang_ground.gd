class_name WangGround
extends RefCounted

# Draws ground from PixelLab Wang tilesets (tools/build_art.py). A map is a grid of
# corner terrains; every 16-unit cell looks at its four corners and takes the atlas
# cell whose corners match. Each tileset pairs grass (lower) with one terrain (upper).
const CELL := 16
const GRASS := 0

static var _cache := {}


static func tileset(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var info := {}
	var path := "res://assets/tilesets/%s.png" % id
	var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
	var file := FileAccess.open("res://assets/tilesets/%s.json" % id, FileAccess.READ)
	if tex and file:
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		info = {"texture": tex, "tile": int(data["tile"]), "cells": data["cells"]}
	_cache[id] = info
	return info


# A seasonal set ("tiles_grass_cliff" + "_summer"), or one without seasons ("tiles_wet_shallow").
static func seasonal(base: String, season: String) -> Dictionary:
	var info := tileset("%s_%s" % [base, season])
	return info if not info.is_empty() else tileset(base)


# terrains: terrain id -> tileset base name without the season ("tiles_grass_cliff"); terrain 0 is the
# lower ground every set shares. corners: PackedInt32Array of (w + 1) * (h + 1) terrain ids, row by row.
# overlay: skip cells whose corners are all terrain 0, to lay a layer over ground drawn before.
static func draw(canvas: CanvasItem, origin: Vector2, w: int, h: int, corners: PackedInt32Array,
		terrains: Dictionary, season: String, overlay := false) -> void:
	var grass := seasonal(terrains.values()[0], season)
	for y in h:
		for x in w:
			var c := [corners[y * (w + 1) + x], corners[y * (w + 1) + x + 1],
				corners[(y + 1) * (w + 1) + x], corners[(y + 1) * (w + 1) + x + 1]]
			if overlay and c == [GRASS, GRASS, GRASS, GRASS]:
				continue
			# The first non-grass corner picks the tileset; other terrains fall back to grass.
			var terrain := GRASS
			for t in c:
				if t != GRASS:
					terrain = t
					break
			var info := grass if terrain == GRASS else seasonal(terrains[terrain], season)
			if info.is_empty():
				continue
			var key := ""
			for t in c:
				key += "1" if t == terrain and terrain != GRASS else "0"
			var index := int(info["cells"].get(key, info["cells"]["0000"]))
			var size: int = info["tile"]
			canvas.draw_texture_rect_region(info["texture"],
				Rect2(origin + Vector2(x, y) * CELL, Vector2(CELL, CELL)),
				Rect2((index % 4) * size, (index / 4) * size, size, size))


# Corners from a cell grid: each vertex takes the most common of its (up to) four cells; ties go
# to the first terrain in `priority`, so thin features such as roads keep their width.
static func corners_from_cells(cells: PackedInt32Array, w: int, h: int, priority: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize((w + 1) * (h + 1))
	for vy in h + 1:
		for vx in w + 1:
			var counts := {}
			for dy in [-1, 0]:
				for dx in [-1, 0]:
					var cx := clampi(vx + dx, 0, w - 1)
					var cy := clampi(vy + dy, 0, h - 1)
					var t := cells[cy * w + cx]
					counts[t] = int(counts.get(t, 0)) + 1
			var best := -1
			var best_count := 0
			for t in counts:
				var n: int = counts[t]
				if n > best_count or (n == best_count and priority.find(t) < priority.find(best)):
					best = t
					best_count = n
			out[vy * (w + 1) + vx] = best
	return out


# A texture's full tile (every corner `side`) for flat fills such as deep water or ice.
static func full_tile(info: Dictionary, upper := true) -> Rect2:
	var index := int(info["cells"]["1111" if upper else "0000"])
	var size: int = info["tile"]
	return Rect2((index % 4) * size, (index / 4) * size, size, size)


static func single(id: String) -> Texture2D:
	var key := "single/" + id
	if not _cache.has(key):
		_cache[key] = load("res://assets/tilesets/single/%s.png" % id) as Texture2D
	return _cache[key]
