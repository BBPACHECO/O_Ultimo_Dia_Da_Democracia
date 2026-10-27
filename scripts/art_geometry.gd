extends RefCounted
## Geometria e superfícies originais. Meshes/texturas pequenos são compartilhados;
## os materiais são individuais para permitir animações locais de cor e dano.

static var _meshes: Dictionary = {}
static var _textures: Dictionary = {}
static var _normals: Dictionary = {}


static func rounded_box(size: Vector3, radius: float = 0.06) -> Mesh:
	var dimensions: Vector3 = size.abs().max(Vector3.ONE * 0.001)
	var half: Vector3 = dimensions * 0.5
	var bevel: float = clampf(radius, 0.0, minf(half.x, minf(half.y, half.z)))
	var key: String = "box:" + str(dimensions) + ":" + str(bevel)
	if _meshes.has(key):
		return _meshes[key]
	if bevel <= 0.0001:
		var box: BoxMesh = BoxMesh.new()
		box.size = dimensions
		_meshes[key] = box
		return box
	var core: Vector3 = (half - Vector3.ONE * bevel).max(Vector3.ZERO)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: int in range(3):
		var u_axis: int = (axis + 1) % 3
		var v_axis: int = (axis + 2) % 3
		var us: Array[float] = [-half[u_axis], -core[u_axis], core[u_axis], half[u_axis]]
		var vs: Array[float] = [-half[v_axis], -core[v_axis], core[v_axis], half[v_axis]]
		for side: float in [-1.0, 1.0]:
			for row: int in range(3):
				for column: int in range(3):
					var vertices: Array[Vector3] = []
					var normals: Array[Vector3] = []
					var uvs: Array[Vector2] = []
					for corner: Vector2i in [Vector2i(column, row), Vector2i(column + 1, row), Vector2i(column + 1, row + 1), Vector2i(column, row + 1)]:
						var p: Vector3 = Vector3.ZERO
						p[axis] = half[axis] * side
						p[u_axis] = us[corner.x]
						p[v_axis] = vs[corner.y]
						var closest: Vector3 = p.clamp(-core, core)
						var normal: Vector3 = (p - closest).normalized()
						vertices.append(closest + normal * bevel)
						normals.append(normal)
						uvs.append(Vector2(p[u_axis] / dimensions[u_axis] + 0.5, p[v_axis] / dimensions[v_axis] + 0.5))
					_triangle(tool, vertices[0], vertices[1], vertices[2], normals[0], normals[1], normals[2], uvs[0], uvs[1], uvs[2])
					_triangle(tool, vertices[0], vertices[2], vertices[3], normals[0], normals[2], normals[3], uvs[0], uvs[2], uvs[3])
	var mesh: ArrayMesh = _finish(tool)
	_meshes[key] = mesh
	return mesh


static func ellipsoid(size: Vector3) -> Mesh:
	var dimensions: Vector3 = size.abs().max(Vector3.ONE * 0.001)
	var key: String = "ellipsoid:" + str(dimensions)
	if _meshes.has(key):
		return _meshes[key]
	var half: Vector3 = dimensions * 0.5
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS: int = 16
	const STACKS: int = 8
	for row: int in range(STACKS):
		for column: int in range(SEGMENTS):
			var positions: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for corner: Vector2i in [Vector2i(column, row), Vector2i(column + 1, row), Vector2i(column + 1, row + 1), Vector2i(column, row + 1)]:
				var u: float = float(corner.x) / SEGMENTS
				var v: float = float(corner.y) / STACKS
				var longitude: float = u * TAU
				var latitude: float = v * PI - PI * 0.5
				var unit: Vector3 = Vector3(cos(latitude) * cos(longitude), sin(latitude), cos(latitude) * sin(longitude))
				positions.append(unit * half)
				normals.append((unit / half).normalized())
				uvs.append(Vector2(u, 1.0 - v))
			_triangle(tool, positions[0], positions[1], positions[2], normals[0], normals[1], normals[2], uvs[0], uvs[1], uvs[2])
			_triangle(tool, positions[0], positions[2], positions[3], normals[0], normals[2], normals[3], uvs[0], uvs[2], uvs[3])
	var mesh: ArrayMesh = _finish(tool)
	_meshes[key] = mesh
	return mesh


static func capsule(radius: float, height: float) -> Mesh:
	var safe_radius: float = maxf(0.001, radius)
	var safe_height: float = maxf(safe_radius * 2.0, height)
	var key: String = "capsule:" + str(safe_radius) + ":" + str(safe_height)
	if _meshes.has(key):
		return _meshes[key]
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = safe_radius
	mesh.height = safe_height
	mesh.radial_segments = 14
	mesh.rings = 2
	_meshes[key] = mesh
	return mesh


static func profile(rings: Array[Vector3], segments: int = 20) -> Mesh:
	if rings.size() < 2:
		return null
	var sides: int = clampi(segments, 8, 32)
	var key: String = "profile:" + str(rings) + ":" + str(sides)
	if _meshes.has(key):
		return _meshes[key]
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var full_height: float = maxf(0.001, rings.back().y - rings.front().y)
	for row: int in range(rings.size() - 1):
		for column: int in range(sides):
			var positions: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for corner: Vector2i in [Vector2i(column, row), Vector2i(column + 1, row), Vector2i(column + 1, row + 1), Vector2i(column, row + 1)]:
				var ring: Vector3 = rings[corner.y]
				var angle: float = float(corner.x) / sides * TAU
				var below: Vector3 = rings[maxi(0, corner.y - 1)]
				var above: Vector3 = rings[mini(rings.size() - 1, corner.y + 1)]
				var upward: Vector3 = Vector3((above.x - below.x) * cos(angle), above.y - below.y, (above.z - below.z) * sin(angle))
				var tangent: Vector3 = Vector3(-ring.x * sin(angle), 0.0, ring.z * cos(angle))
				positions.append(Vector3(ring.x * cos(angle), ring.y, ring.z * sin(angle)))
				normals.append(upward.cross(tangent).normalized())
				uvs.append(Vector2(float(corner.x) / sides, 1.0 - (ring.y - rings.front().y) / full_height))
			_triangle(tool, positions[0], positions[1], positions[2], normals[0], normals[1], normals[2], uvs[0], uvs[1], uvs[2])
			_triangle(tool, positions[0], positions[2], positions[3], normals[0], normals[2], normals[3], uvs[0], uvs[2], uvs[3])
	for end: int in [0, rings.size() - 1]:
		var ring: Vector3 = rings[end]
		var cap_normal: Vector3 = Vector3.DOWN if end == 0 else Vector3.UP
		for column: int in range(sides):
			var a: float = float(column) / sides * TAU
			var b: float = float(column + 1) / sides * TAU
			_triangle(tool, Vector3(0.0, ring.y, 0.0), Vector3(ring.x * cos(a), ring.y, ring.z * sin(a)), Vector3(ring.x * cos(b), ring.y, ring.z * sin(b)), cap_normal, cap_normal, cap_normal, Vector2(0.5, 0.5), Vector2(cos(a), sin(a)) * 0.5 + Vector2.ONE * 0.5, Vector2(cos(b), sin(b)) * 0.5 + Vector2.ONE * 0.5)
	var mesh: ArrayMesh = _finish(tool)
	_meshes[key] = mesh
	return mesh


static func _finish(tool: SurfaceTool) -> ArrayMesh:
	tool.generate_tangents()
	tool.index()
	return tool.commit()

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var cross: Vector3 = (b - a).cross(c - a)
	if cross.length_squared() < 0.00000000001:
		return
	# Godot considera a ordem horária como face frontal.
	if cross.dot(na + nb + nc) > 0.0:
		_vertex(tool, a, na, ua)
		_vertex(tool, c, nc, uc)
		_vertex(tool, b, nb, ub)
	else:
		_vertex(tool, a, na, ua)
		_vertex(tool, b, nb, ub)
		_vertex(tool, c, nc, uc)


static func _vertex(tool: SurfaceTool, at: Vector3, normal: Vector3, uv: Vector2) -> void:
	tool.set_normal(normal)
	tool.set_uv(uv)
	tool.add_vertex(at)


static func surface(base: Color, kind: String = "plain") -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = {"cloth": 0.93, "skin": 0.85, "metal": 0.62, "wood": 0.86, "leaf": 0.93}.get(kind, 0.96)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.texture_repeat = true
	if kind != "plain":
		_ensure_texture(kind)
		material.albedo_texture = _textures[kind]
		if _normals.has(kind):
			material.normal_enabled = true
			material.normal_texture = _normals[kind]
			material.normal_scale = 0.28
	return material


static func _ensure_texture(kind: String) -> void:
	if _textures.has(kind):
		return
	const PIXELS: int = 128
	var image: Image = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGB8)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(PIXELS * PIXELS)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = absi(kind.hash()) % 32768
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	for y: int in range(PIXELS):
		for x: int in range(PIXELS):
			var u: float = float(x) / PIXELS
			var v: float = float(y) / PIXELS
			var a: float = lerpf(noise.get_noise_2d(x, y), noise.get_noise_2d(x - PIXELS, y), u)
			var b: float = lerpf(noise.get_noise_2d(x, y - PIXELS), noise.get_noise_2d(x - PIXELS, y - PIXELS), u)
			var n: float = lerpf(a, b, v)
			var value: float = 0.96 + n * 0.10
			match kind:
				"skin":
					value = 0.98 + n * 0.025
				"cloth":
					value = 0.95 + n * 0.045 + sin((x + 0.5) * PI) * 0.012 + cos(y * PI) * 0.012
				"wood", "bark":
					value = 0.94 + n * 0.06 + sin(u * TAU * 9.0 + sin(v * TAU * 2.0)) * 0.035
				"paving":
					var joint: bool = x % 32 < 1 or y % 32 < 1
					value = 0.82 if joint else 0.97 + n * 0.04
				"asphalt":
					value = 0.94 + n * 0.09 + sin(float(x * 41 + y * 67)) * 0.025
				"metal":
					value = 0.98 + n * 0.02
			value = clampf(value, 0.76, 1.0)
			heights[y * PIXELS + x] = value
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	_textures[kind] = ImageTexture.create_from_image(image)
	if kind in ["stone", "plaster", "asphalt", "paving", "bark", "wood"]:
		var normal: Image = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGB8)
		for y: int in range(PIXELS):
			for x: int in range(PIXELS):
				var dx: float = heights[y * PIXELS + (x + 1) % PIXELS] - heights[y * PIXELS + (x + PIXELS - 1) % PIXELS]
				var dy: float = heights[((y + 1) % PIXELS) * PIXELS + x] - heights[((y + PIXELS - 1) % PIXELS) * PIXELS + x]
				var n: Vector3 = Vector3(-dx * 3.0, dy * 3.0, 1.0).normalized()
				normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
		normal.generate_mipmaps()
		_normals[kind] = ImageTexture.create_from_image(normal)


static func shadow_texture() -> Texture2D:
	if _textures.has("_contact_shadow"):
		return _textures["_contact_shadow"]
	const PIXELS: int = 64
	var image: Image = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	for y: int in range(PIXELS):
		for x: int in range(PIXELS):
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) / PIXELS * 2.0 - Vector2.ONE
			var radius: float = p.length()
			var alpha: float = pow(maxf(0.0, 1.0 - radius * radius), 2.4) * 0.32
			image.set_pixel(x, y, Color(0.06, 0.08, 0.07, alpha))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures["_contact_shadow"] = texture
	return texture
