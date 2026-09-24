class_name LighthouseFloorInfo


static func number() -> int:
	return int(Router.current_map.substr(3)) if Router.current_map.begins_with("lh_") else 0
