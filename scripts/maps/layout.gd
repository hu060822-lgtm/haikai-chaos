class_name Layout
extends RefCounted
## The floor plan of a big competitive map (C5), as a grid of cells. A map starts solid
## ('#') and carves its rooms, lanes and corridors out of it in world metres; the rest
## stays rock. The plan then does three jobs:
##
##   build    the solid cells become a few big wall blocks (rectangles merged greedily),
##            each with an invisible column above it up to CEILING, plus a lid over the
##            whole map: nothing can be climbed out of, whatever the movement does
##   nav      bots find their way on it (A* over open cells, then straightened), so they
##            can walk lanes and turn corners instead of walking into walls
##   draw     the plan as text (for tests and the minimap)
##
## Cell kinds: '#' solid, '.' open floor, 'x' open but built by hand (a map's own hall),
## 'o' blocked for bots but built by hand (a tower, a table), 'c' low cover (bots go round),
## anything else is open floor of a named area ('a' site A, 'b' site B, 's' spawn...).

const CEILING := 40.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
## The invisible barriers: bodies collide with them, shots and wall probes don't.
const BOUNDS_LAYER := Geo.BOUNDS

var rect: Rect2
var cell: float
var cols: int
var rows: int
var grid: PackedByteArray


func _init(area: Rect2, cell_size := 2.0) -> void:
	rect = area
	cell = cell_size
	cols = int(ceil(area.size.x / cell))
	rows = int(ceil(area.size.y / cell))
	grid = PackedByteArray()
	grid.resize(cols * rows)
	grid.fill("#".unicode_at(0))


func _index(c: int, r: int) -> int:
	return r * cols + c


func inside(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cols and r < rows


func at(c: int, r: int) -> String:
	return char(grid[_index(c, r)]) if inside(c, r) else "#"


func set_cell(c: int, r: int, ch: String) -> void:
	if inside(c, r):
		grid[_index(c, r)] = ch.unicode_at(0)


func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor((pos.x - rect.position.x) / cell)), int(floor((pos.z - rect.position.y) / cell)))


func centre(c: int, r: int, y := 0.0) -> Vector3:
	return Vector3(rect.position.x + (c + 0.5) * cell, y, rect.position.y + (r + 0.5) * cell)


func kind_at(pos: Vector3) -> String:
	var g := cell_of(pos)
	return at(g.x, g.y)


## Sets every cell whose centre is in `area` (world x/z) to `ch`.
func carve(area: Rect2, ch := ".") -> void:
	var a := cell_of(Vector3(area.position.x + 0.01, 0, area.position.y + 0.01))
	var b := cell_of(Vector3(area.end.x - 0.01, 0, area.end.y - 0.01))
	for r in range(maxi(a.y, 0), mini(b.y + 1, rows)):
		for c in range(maxi(a.x, 0), mini(b.x + 1, cols)):
			set_cell(c, r, ch)


## carve() and the same turned half round the map's centre (the maps are fair that way).
func carve2(area: Rect2, ch := ".") -> void:
	carve(area, ch)
	carve(turned(area), ch)


func turned(area: Rect2) -> Rect2:
	var mid := rect.get_center()
	return Rect2(mid * 2.0 - area.end, area.size)


static func turn(p: Vector3, mid := Vector2.ZERO) -> Vector3:
	return Vector3(mid.x * 2.0 - p.x, p.y, mid.y * 2.0 - p.z)


func solid(c: int, r: int) -> bool:
	return at(c, r) == "#"


func walkable(c: int, r: int) -> bool:
	var k := at(c, r)
	return k != "#" and k != "o" and k != "c"


## The cells of `chars` merged into rectangles (in cells): Rect2i(col, row, w, h).
func cell_rects(chars: String) -> Array[Rect2i]:
	var used := PackedByteArray()
	used.resize(cols * rows)
	var out: Array[Rect2i] = []
	for r in rows:
		for c in cols:
			if used[_index(c, r)] != 0 or not chars.contains(at(c, r)):
				continue
			var w := 1
			while c + w < cols and used[_index(c + w, r)] == 0 and chars.contains(at(c + w, r)):
				w += 1
			var h := 1
			var grow := true
			while grow and r + h < rows:
				for i in w:
					if used[_index(c + i, r + h)] != 0 or not chars.contains(at(c + i, r + h)):
						grow = false
						break
				if grow:
					h += 1
			for rr in h:
				for cc in w:
					used[_index(c + cc, r + rr)] = 1
			out.append(Rect2i(c, r, w, h))
	return out


## The same, in world metres (x/z).
func rects(chars: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for q in cell_rects(chars):
		out.append(Rect2(rect.position + Vector2(q.position) * cell, Vector2(q.size) * cell))
	return out


## The solid cells as walls: `make(size, centre)` builds each one (the map's own look),
## then the invisible columns above and the lid go on top.
func build_walls(parent: Node3D, height: float, make: Callable) -> void:
	for w in rects("#"):
		make.call(Vector3(w.size.x, height, w.size.y), Vector3(w.get_center().x, height / 2.0, w.get_center().y))
		barrier(parent, Vector3(w.size.x, CEILING - height, w.size.y), Vector3(w.get_center().x, (CEILING + height) / 2.0, w.get_center().y))
	seal(parent)


## A lid over the map and walls round its edge, all invisible.
func seal(parent: Node3D, margin := 2.0) -> void:
	var r := rect.grow(margin)
	barrier(parent, Vector3(r.size.x, 1.0, r.size.y), Vector3(r.get_center().x, CEILING + 0.5, r.get_center().y))
	for side in 4:
		var horizontal := side < 2
		var size := Vector3(r.size.x + 2.0, CEILING + 20.0, 1.0) if horizontal else Vector3(1.0, CEILING + 20.0, r.size.y + 2.0)
		var at_edge := Vector3(r.get_center().x, CEILING / 2.0 - 10.0, r.position.y - 0.5 if side == 0 else r.end.y + 0.5) if horizontal \
			else Vector3(r.position.x - 0.5 if side == 2 else r.end.x + 0.5, CEILING / 2.0 - 10.0, r.get_center().y)
		barrier(parent, size, at_edge)


static func barrier(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = BOUNDS_LAYER
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


# --- Finding the way -------------------------------------------------------------------

## Points from `from` to `to` (world), corners only. Empty when there's no way.
func path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var s := _nearest_open(cell_of(from))
	var g := _nearest_open(cell_of(to))
	var out: Array[Vector3] = []
	if s.x < 0 or g.x < 0:
		return out
	if s == g:
		out.append(to)
		return out
	var n_cells := cols * rows
	var cost := PackedFloat32Array()
	cost.resize(n_cells)
	cost.fill(INF)
	var came := PackedInt32Array()
	came.resize(n_cells)
	came.fill(-1)
	var done := PackedByteArray()
	done.resize(n_cells)
	var si := _index(s.x, s.y)
	var gi := _index(g.x, g.y)
	cost[si] = 0.0
	var heap := _Heap.new()
	heap.push(_h(s, g), si)
	var found := false
	while not heap.empty():
		var ci := heap.pop()
		if done[ci] != 0:
			continue
		done[ci] = 1
		if ci == gi:
			found = true
			break
		var cur := Vector2i(ci % cols, ci / cols)
		for d in DIRS:
			var n: Vector2i = cur + d
			if not walkable(n.x, n.y):
				continue
			if d.x != 0 and d.y != 0 and (not walkable(cur.x + d.x, cur.y) or not walkable(cur.x, cur.y + d.y)):
				continue
			var ni := _index(n.x, n.y)
			# Hug walls less: a cell next to rock costs a bit more.
			var step := (1.41421 if d.x != 0 and d.y != 0 else 1.0) + (0.6 if _near_rock(n) else 0.0)
			var c2 := cost[ci] + step
			if c2 < cost[ni]:
				cost[ni] = c2
				came[ni] = ci
				heap.push(c2 + _h(n, g), ni)
	if not found:
		return out
	var cells: Array[Vector2i] = [g]
	var k := gi
	while k != si:
		k = came[k]
		cells.append(Vector2i(k % cols, k / cols))
	cells.reverse()
	# Straighten: keep a corner only where the straight line to the next one is blocked.
	var keep: Array[Vector2i] = [cells[0]]
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not clear(keep[-1], cells[j]):
			j -= 1
		keep.append(cells[j])
		i = j
	for q in range(1, keep.size()):
		out.append(centre(keep[q].x, keep[q].y, to.y))
	out[-1] = to
	return out


func _h(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


func _near_rock(n: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not walkable(n.x + d.x, n.y + d.y):
			return true
	return false


## True when a bot can walk straight from cell a to cell b (a body-wide line of open cells).
func clear(a: Vector2i, b: Vector2i) -> bool:
	var pa := Vector2(a) + Vector2(0.5, 0.5)
	var pb := Vector2(b) + Vector2(0.5, 0.5)
	var n := int(ceil(pa.distance_to(pb) * 3.0)) + 1
	var side := (pb - pa).normalized().orthogonal() * 0.3
	for k in n + 1:
		var p := pa.lerp(pb, float(k) / n)
		for q in [p, p + side, p - side]:
			if not walkable(int(floor(q.x)), int(floor(q.y))):
				return false
	return true


func _nearest_open(g: Vector2i) -> Vector2i:
	if walkable(g.x, g.y):
		return g
	for radius in range(1, 6):
		for r in range(g.y - radius, g.y + radius + 1):
			for c in range(g.x - radius, g.x + radius + 1):
				if walkable(c, r):
					return Vector2i(c, r)
	return Vector2i(-1, -1)


## Open cells spread over the plan (at least `spacing` cells apart), for bots to wander.
func wander_points(spacing := 5) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for r in range(spacing / 2, rows, spacing):
		for c in range(spacing / 2, cols, spacing):
			if walkable(c, r) and not _near_rock(Vector2i(c, r)):
				out.append(centre(c, r))
	return out


## The plan as text, one line per row (north at the top).
func draw() -> String:
	var lines := PackedStringArray()
	for r in rows:
		var line := ""
		for c in cols:
			line += at(c, r)
		lines.append(line)
	return "\n".join(lines)


## A binary min-heap of [priority, value] for the path search.
class _Heap:
	var keys := PackedFloat32Array()
	var vals := PackedInt32Array()

	func empty() -> bool:
		return keys.is_empty()

	func push(key: float, val: int) -> void:
		keys.append(key)
		vals.append(val)
		var i := keys.size() - 1
		while i > 0:
			var up := (i - 1) / 2
			if keys[up] <= keys[i]:
				break
			_swap(i, up)
			i = up

	func pop() -> int:
		var top := vals[0]
		var last := keys.size() - 1
		_swap(0, last)
		keys.resize(last)
		vals.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < last and keys[l] < keys[m]:
				m = l
			if r < last and keys[r] < keys[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var k := keys[a]
		keys[a] = keys[b]
		keys[b] = k
		var v := vals[a]
		vals[a] = vals[b]
		vals[b] = v
