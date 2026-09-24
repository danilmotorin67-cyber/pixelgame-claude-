extends Node

func pick(npc_id: String) -> Dictionary:
	return {"emo": "neutral", "text": "npc.%s.greet.generic" % npc_id}
