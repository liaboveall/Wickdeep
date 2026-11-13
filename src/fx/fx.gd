class_name Fx
extends RefCounted
## One-shot visual effects: sprite animations, particle bursts, damage numbers, rings, telegraphs.
## Everything here frees itself when it is done.

const Z_TELEGRAPH := -5
const Z_PARTICLES := 19
const Z_ANIM := 20
const Z_RING := 25
const Z_TEXT := 40
## Telegraph markers join this group so the test bot can find and avoid them.
const TELEGRAPH_GROUP := &"telegraphs"

static var _unshaded: CanvasItemMaterial
static var _shaders := {}


## Material that ignores 2D lighting: for things that must stay readable in the dark.
static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## A fresh material using one of the shaders in src/fx/shaders/.
static func shader_material(shader_name: String) -> ShaderMaterial:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://src/fx/shaders/%s.gdshader" % shader_name)
	var m := ShaderMaterial.new()
	m.shader = _shaders[shader_name]
	return m


## A particle colour ramp that fades out (optionally fading in first).
static func fade_ramp(fade_in := 0.0, fade_out_from := 0.0) -> Gradient:
	var ramp := Gradient.new()
	if fade_in <= 0.0:
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
	else:
		ramp.offsets = PackedFloat32Array([0.0, fade_in, fade_out_from, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return ramp


## Play a sprite-sheet animation once at `pos`.
static func anim(parent: Node, sheet: String, pos: Vector2, anim_name := "pop", z := Z_ANIM, scale_ := 1.0,
		glow := true, rot := 0.0) -> AnimatedSprite2D:
	var s := SpriteLib.make_sprite(sheet, anim_name)
	s.position = pos
	s.z_index = z
	s.scale = Vector2(scale_, scale_)
	s.rotation = rot
	if glow:
		s.material = unshaded()
	s.animation_finished.connect(s.queue_free)
	parent.add_child(s)
	return s


## A puff of ground dust (footsteps, landings); drawn under the actors and lit by the scene.
static func dust(parent: Node, pos: Vector2, scale_ := 1.0) -> void:
	anim(parent, "dust", pos, "pop", -1, scale_, false)


static func burst(parent: Node, pos: Vector2, color: Color, count := 8, speed := 70.0, life := 0.45,
		size := 2.0, glow := true, gravity := 0.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = Z_PARTICLES
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 2.0
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size
	p.scale_amount_max = size
	p.color = color
	p.color_ramp = fade_ramp()
	if glow:
		p.material = unshaded()
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Floating damage number.
static func number(parent: Node, pos: Vector2, value: float, color := UiTheme.CREAM, big := false) -> void:
	if not Settings.damage_numbers:
		return
	var l := UiTheme.pixel_label(str(int(round(value))), color, true)
	l.z_index = Z_TEXT
	l.material = unshaded()
	l.position = pos + Vector2(randf_range(-4, 4) - 4, -14)
	if big:
		l.scale = Vector2(2, 2)
	parent.add_child(l)
	_float_away(l, 12.0, 0.45, 0.35, 0.25)


## Floating caption ("+2 生命").
static func text(parent: Node, pos: Vector2, msg: String, color := UiTheme.GOLD) -> void:
	var l := UiTheme.outlined(UiTheme.label(msg, color))
	l.z_index = Z_TEXT
	l.material = unshaded()
	parent.add_child(l)
	l.position = pos - Vector2(l.get_minimum_size().x / 2.0, 20)
	_float_away(l, 14.0, 0.9, 0.7, 0.4)


static func _float_away(l: Label, rise: float, rise_time: float, fade_delay: float, fade_time: float) -> void:
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - rise, rise_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, fade_time).set_delay(fade_delay)
	tw.tween_callback(l.queue_free)


## Expanding shockwave ring.
static func ring(parent: Node, pos: Vector2, radius: float, color: Color, duration := 0.35, width := 2.0) -> void:
	var r := RingFx.new()
	r.position = pos
	r.max_radius = radius
	r.color = color
	r.duration = duration
	r.width = width
	parent.add_child(r)


## A light that pops and fades (explosions, flares).
static func light_flash(parent: Node, pos: Vector2, color: Color, energy := 1.4, size := 1.0, duration := 0.25) -> void:
	var l := PointLight2D.new()
	l.texture = Lights.radial()
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = size
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


## A fading copy of a sprite's current frame (dash trail).
static func afterimage(parent: Node, source: AnimatedSprite2D, tint: Color, duration := 0.22) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	ghost.flip_h = source.flip_h
	ghost.global_position = source.global_position
	ghost.modulate = tint
	ghost.material = unshaded()
	ghost.z_index = -1
	parent.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, duration)
	tw.tween_callback(ghost.queue_free)


## Expanding ring (flare, slams, shockwaves).
class RingFx:
	extends Node2D
	var max_radius := 40.0
	var color := Color.WHITE
	var duration := 0.35
	var width := 2.0
	var t := 0.0

	func _ready() -> void:
		z_index = Fx.Z_RING
		material = Fx.unshaded()

	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / duration
		var r := lerpf(4.0, max_radius, 1.0 - pow(1.0 - k, 3.0))
		var c := color
		c.a *= 1.0 - k
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, width)
		if k < 0.3:
			var inner := color
			inner.a = 0.25 * (1.0 - k / 0.3)
			draw_circle(Vector2.ZERO, r, inner)


## Pulsing ground marker shown before something lands there (spawns, wax rain, slams).
class Telegraph:
	extends Node2D
	var radius := 10.0
	var color := Color(1, 0.3, 0.25)
	var duration := 0.8
	var t := 0.0

	func _ready() -> void:
		z_index = Fx.Z_TELEGRAPH
		material = Fx.unshaded()
		add_to_group(Fx.TELEGRAPH_GROUP)

	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / duration
		var fill := color
		fill.a = 0.18 + 0.12 * sin(t * 18.0)
		draw_circle(Vector2.ZERO, radius, fill)
		var edge := color
		edge.a = 0.85
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, edge, 1.0)
		draw_arc(Vector2.ZERO, radius * k, 0, TAU, 32, edge, 1.0)
