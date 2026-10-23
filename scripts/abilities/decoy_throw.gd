class_name DecoyThrow
extends Ability
## DECOY's ability (C6): sends a Decoy running from your feet the way you look, holding
## your gun. Two charges, so one can cover the other (or cover you).


func press() -> void:
	if not alive():
		return
	if charges < 1.0:
		say("誘餌還在冷卻")
		return
	spend()
	var fwd := -aim().basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var w = user.get("weapon")
	Deploy.spawn("decoy", user, {"at": user.global_position + fwd * 0.6, "dir": fwd,
		"build": w.build if w != null else {}, "name": str(user.get("display_name"))})
	Sfx.play(user, "dash", -12.0)
