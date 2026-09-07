extends CanvasLayer
func refresh(fighters: Array, remaining: float, paused: bool, result: String) -> void:
	$Root/Status.text = "P1 HP %.1f  AMMO %d/%d   |   %02d sec   |   P2 HP %.1f  AMMO %d/%d\nP1 WASD / F fire / SPACE dodge / V melee / R reload / E gun\nP2 arrows / J fire / K dodge / L melee / P reload / O gun   ESC pause" % [fighters[0].hp,fighters[0].clip,fighters[0].reserve,maxi(0,int(remaining)),fighters[1].hp,fighters[1].clip,fighters[1].reserve]
	$Root/Message.text = "PAUSED" if paused else (result+" / ENTER restart" if result != "" else "")
