extends Area2D
## Surreal gate with a small, perspective view into the next stage.

signal reached
var phase := 0.0
var used := false
var color_a := Color("82dfff")
var color_b := Color("ffb26c")
var preview_data: Dictionary = {}

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var collider := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 25.0
    collider.shape = shape
    add_child(collider)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    phase += delta * 3.0
    queue_redraw()

func _on_body_entered(body: Node2D) -> void:
    if not used and body.has_method("bounce"):
        used = true
        reached.emit()

func _draw() -> void:
    var pulse := 1.0 + sin(phase * 0.8) * 0.025
    var next_theme: Dictionary = preview_data.get("theme", {})
    var portal_color := color_a
    var destination_color := color_b

    # A soft, layered aura replaces the old solid-looking portal texture.
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.78, 1.28))
    _draw_ellipse(43.0 * pulse, 59.0 * pulse, Color(destination_color, 0.035))
    _draw_ellipse(39.0 * pulse, 55.0 * pulse, Color(portal_color, 0.045))
    _draw_ellipse(35.0 * pulse, 51.0 * pulse, Color(destination_color, 0.08))

    # The aperture is transparent to the old world; only the destination scene is drawn here.
    _draw_ellipse(30.0, 47.0, Color("080b19"))
    _draw_preview_scene(next_theme)

    # The outer rim belongs to the world ahead; the inner lip belongs to this world.
    _draw_ellipse_outline(36.5 * pulse, 52.0 * pulse, Color(destination_color, 0.28), 8.0)
    _draw_ellipse_outline(34.0 * pulse, 49.5 * pulse, Color(destination_color, 0.95), 3.2)
    _draw_ellipse_outline(30.8 * pulse, 46.0 * pulse, Color(portal_color, 0.95), 4.0)
    _draw_ellipse_outline(28.7 * pulse, 43.8 * pulse, Color(portal_color.lightened(0.45), 0.78), 1.0)

    # A few drifting motes make the edge feel dimensional without obscuring the view.
    for mote_index in range(5):
        var angle := phase * 0.18 + float(mote_index) * TAU / 5.0
        var mote_position := Vector2(cos(angle) * 39.0, sin(angle) * 52.0)
        draw_circle(mote_position, 1.1 + (mote_index % 2) * 0.55, Color(destination_color, 0.7))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_preview_scene(theme: Dictionary) -> void:
    var sky_color := Color(theme.get("background_upper", "11132f"))
    var horizon_color := Color(theme.get("background_horizon", "55518b"))
    var floor_color := Color(theme.get("background_floor", "282642"))
    var accent_color := Color(theme.get("platform_accent", "ffe58d"))
    var platform_color := Color(theme.get("platform_static", "514d73"))
    var highlight_color := Color(theme.get("platform_highlight", "a49ce0"))

    # Atmospheric bands and a distant vanishing point suggest a view through space.
    _draw_ellipse(30.0, 47.0, sky_color)
    _draw_ellipse(25.0, 38.0, Color(horizon_color, 0.34))
    _draw_ellipse(18.0, 27.0, Color(floor_color, 0.32))
    _draw_ellipse_outline(22.0, 35.0, Color(horizon_color, 0.22), 1.0)
    draw_circle(Vector2(0.0, -17.0), 5.0, Color(accent_color, 0.12))
    draw_circle(Vector2(0.0, -17.0), 1.8, Color(accent_color, 0.72))

    # Fine rays converge toward the center, selling a forward-looking camera angle.
    for ray_index in range(7):
        var ray_fraction := float(ray_index) / 6.0
        var ray_edge := 30.0 * sqrt(maxf(0.0, 1.0 - pow(41.0 / 47.0, 2.0))) - 1.0
        var ray_end := lerpf(-ray_edge, ray_edge, ray_fraction)
        draw_line(Vector2(ray_end * 0.22, -15.0), Vector2(ray_end, 41.0), Color(accent_color, 0.10), 0.8, true)

    for rect: Rect2 in preview_data.get("platforms", []):
        _draw_preview_platform(rect, platform_color, highlight_color)
    for platform: Dictionary in preview_data.get("moving", []):
        _draw_preview_platform(platform["rect"], accent_color.darkened(0.24), accent_color)
    for hazard: Rect2 in preview_data.get("hazards", []):
        var hazard_position := _project_point(hazard.position + Vector2(hazard.size.x * 0.5, 0.0))
        var hazard_width := maxf(2.0, hazard.size.x / 1152.0 * 48.0)
        draw_line(hazard_position, hazard_position + Vector2(hazard_width, 0.0), Color(accent_color, 0.85), 1.4, true)

    # A hazy destination glow and scattered stars add depth without a pasted-on backdrop.
    for star_index in range(12):
        var star_x := sin(float(star_index) * 19.7 + 1.3) * 24.0
        var star_y := -36.0 + float((star_index * 17) % 70)
        var star_edge := 30.0 * sqrt(maxf(0.0, 1.0 - pow(star_y / 47.0, 2.0)))
        if absf(star_x) < star_edge:
            draw_circle(Vector2(star_x, star_y), 0.45 + float(star_index % 3) * 0.2, Color("e5e9ff", 0.62))

func _draw_preview_platform(rect: Rect2, base_color: Color, top_color: Color) -> void:
    var center := _project_point(rect.position + Vector2(rect.size.x * 0.5, 0.0))
    var depth := clampf((center.y + 39.0) / 78.0, 0.0, 1.0)
    var perspective := lerpf(0.52, 1.0, depth)
    var width := maxf(3.0, rect.size.x / 1152.0 * 52.0 * perspective)
    var half_width := width * 0.5
    var edge := 30.0 * sqrt(maxf(0.0, 1.0 - pow(center.y / 47.0, 2.0))) - 1.0
    var left := clampf(center.x - half_width, -edge, edge)
    var right := clampf(center.x + half_width, -edge, edge)
    var thickness := clampf(rect.size.y * 0.055, 1.4, 4.0)
    if right <= left:
        return
    var platform_points := PackedVector2Array([
        Vector2(left, center.y), Vector2(right, center.y),
        Vector2(right - 0.8, center.y + thickness), Vector2(left + 0.8, center.y + thickness)
    ])
    draw_colored_polygon(platform_points, base_color)
    draw_line(Vector2(left, center.y), Vector2(right, center.y), Color(top_color, 0.95), 1.2, true)
    draw_line(Vector2(left + 1.0, center.y + thickness), Vector2(right - 1.0, center.y + thickness), Color(base_color.darkened(0.35), 0.9), 0.8, true)

func _project_point(stage_position: Vector2) -> Vector2:
    var depth := clampf((stage_position.y - 330.0) / 270.0, 0.0, 1.0)
    var perspective := lerpf(0.52, 1.0, depth)
    var x := (stage_position.x / 1152.0 - 0.5) * 52.0 * perspective
    var y := lerpf(-39.0, 39.0, depth)
    var edge := 30.0 * sqrt(maxf(0.0, 1.0 - pow(y / 47.0, 2.0))) - 1.0
    return Vector2(clampf(x, -edge, edge), y)

func _draw_ellipse(radius_x: float, radius_y: float, color: Color) -> void:
    draw_colored_polygon(_ellipse_points(radius_x, radius_y), color)

func _draw_ellipse_outline(radius_x: float, radius_y: float, color: Color, width: float) -> void:
    var points := _ellipse_points(radius_x, radius_y, 96)
    points.append(points[0])
    draw_polyline(points, color, width, true)

func _ellipse_points(radius_x: float, radius_y: float, point_count: int = 72) -> PackedVector2Array:
    var points := PackedVector2Array()
    for point_index in range(point_count):
        var angle := TAU * float(point_index) / float(point_count)
        points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
    return points
