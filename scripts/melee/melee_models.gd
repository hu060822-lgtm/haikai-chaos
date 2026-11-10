class_name MeleeModels
## The melee weapons' look (C13): small boxes and cylinders in the Counterform palette, the
## grip at the origin and the business end along -Z (the way a gun points), so the first-
## person swing and the bench preview can hold them the same way.


## `hand`: a glove round the grip (first person).
static func build(id: String, hand := false) -> Node3D:
	var root := Node3D.new()
	if hand and Melee.valid(id) != "fist":
		_box(root, Vector3(0.07, 0.085, 0.09), Vector3(0.0, -0.01, 0.0), Color("#2f3336"))
	root.name = "Melee_%s" % id
	var c: Color = Melee.info(id).color
	match Melee.valid(id):
		"knife":
			_box(root, Vector3(0.028, 0.034, 0.11), Vector3(0, 0, 0.02), Color("#2a2d30"))
			_box(root, Vector3(0.06, 0.012, 0.016), Vector3(0, 0, -0.04), Color("#3a3d40"), 0.6)
			_box(root, Vector3(0.008, 0.032, 0.17), Vector3(0, 0.004, -0.13), c, 0.9)
		"axe":
			_box(root, Vector3(0.032, 0.032, 0.62), Vector3(0, 0, -0.2), Color("#6b4a2e"))
			_box(root, Vector3(0.018, 0.15, 0.1), Vector3(0, 0.07, -0.5), c, 0.5)
			_box(root, Vector3(0.012, 0.05, 0.04), Vector3(0, -0.04, -0.5), Color("#2a2d30"), 0.6)
		"sledge":
			_box(root, Vector3(0.03, 0.03, 0.58), Vector3(0, 0, -0.18), Color("#3a3d40"), 0.4)
			_box(root, Vector3(0.11, 0.11, 0.22), Vector3(0, 0, -0.5), c, 0.7).rotation.y = PI / 2.0
		"baton":
			_cyl(root, 0.018, 0.42, Vector3(0, 0, -0.12), Color("#1e2023"))
			var tip := _cyl(root, 0.022, 0.05, Vector3(0, 0, -0.35), c)
			var m := tip.material_override as StandardMaterial3D
			m.emission_enabled = true
			m.emission = c * 1.4
		"sickle":
			_box(root, Vector3(0.03, 0.03, 0.2), Vector3(0, 0, 0.0), Color("#6b4a2e"))
			_box(root, Vector3(0.01, 0.03, 0.16), Vector3(0, 0.05, -0.12), c, 0.8).rotation.x = 0.7
			_box(root, Vector3(0.01, 0.03, 0.1), Vector3(0, 0.1, -0.03), c, 0.8).rotation.x = 1.6
			for i in 5:
				_box(root, Vector3(0.014, 0.014, 0.03), Vector3(0, -0.01 - i * 0.006, 0.12 + i * 0.035), Color("#8a8d90"), 0.8)
		"fist":
			_box(root, Vector3(0.1, 0.08, 0.12), Vector3(0, 0, -0.02), Color("#2a2d30"))
			var pad := _box(root, Vector3(0.105, 0.05, 0.03), Vector3(0, 0.0, -0.09), c, 0.4)
			(pad.material_override as StandardMaterial3D).emission_enabled = true
			(pad.material_override as StandardMaterial3D).emission = c * 0.8
			_cyl(root, 0.022, 0.07, Vector3(0.035, 0.05, 0.04), Color("#5a5d60")).rotation.x = 0.0
			_cyl(root, 0.022, 0.07, Vector3(-0.035, 0.05, 0.04), Color("#5a5d60"))
	return root


static func _mat(c: Color, metal := 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.55
	return m


static func _box(root: Node3D, size: Vector3, at: Vector3, c: Color, metal := 0.2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c, metal)
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## A cylinder lying along Z.
static func _cyl(root: Node3D, r: float, length: float, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r
	cy.bottom_radius = r
	cy.height = length
	mi.mesh = cy
	mi.material_override = _mat(c, 0.3)
	mi.position = at
	mi.rotation.x = PI / 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
