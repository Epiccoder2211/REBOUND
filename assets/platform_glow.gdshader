shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float pulse = 0.82 + 0.18 * sin(TIME * 2.2);
	COLOR = vec4(COLOR.rgb * pulse, COLOR.a * pulse);
}