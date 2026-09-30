class_name WorldState
extends RefCounted

## Per-run data. Restarting a run intentionally creates a fresh state.
var encounters: Dictionary = {}
var discovered_chunks: Dictionary = {}

func encounter(id: StringName) -> Dictionary:
	if not encounters.has(id):
		encounters[id] = {
			"discovered": false, "cleared": false, "reward_spawned": false,
			"reward_claimed": false, "dead_members": {}, "rewarded_members": {}
		}
	return encounters[id]

func claim_member_reward(id: StringName, member_id: String) -> bool:
	var data := encounter(id)
	if data.rewarded_members.has(member_id):
		return false
	data.rewarded_members[member_id] = true
	return true
