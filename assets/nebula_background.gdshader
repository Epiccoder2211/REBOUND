shader_type canvas_item;

uniform vec4 upper_color : source_color = vec4(0.025, 0.035, 0.095, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.13, 0.10, 0.25, 1.0);
uniform vec4 floor_color : source_color = vec4(0.08, 0.075, 0.16, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float horizon = smoothstep(0.18, 0.9, uv.y);
	vec3 color = mix(upper_color.rgb, horizon_color.rgb, horizon * 0.58);
	color = mix(color, floor_color.rgb, smoothstep(0.72, 0.98, uv.y) * 0.72);

	vec2 cloud_uv = uv * vec2(3.2, 5.2) + vec2(TIME * 0.012, -TIME * 0.004);
	float cloud = noise(cloud_uv) * 0.65 + noise(cloud_uv * 2.1 + 8.0) * 0.35;
	float cloud_mask = smoothstep(0.48, 0.88, cloud) * (1.0 - smoothstep(0.74, 1.0, uv.y));
	color += vec3(0.20, 0.14, 0.42) * cloud_mask * 0.22;

	float cyan_bloom = exp(-length((uv - vec2(0.18, 0.55)) * vec2(1.0, 1.45)) * 4.0);
	float gold_bloom = exp(-length((uv - vec2(0.91, 0.16)) * vec2(1.0, 1.4)) * 5.0);
	color += vec3(0.08, 0.34, 0.56) * cyan_bloom * 0.30;
	color += vec3(0.65, 0.34, 0.10) * gold_bloom * 0.20;

	vec2 grid = uv * vec2(92.0, 54.0);
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - 0.5;
	float star_seed = hash(cell);
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.1 + star_seed * 2.0) + star_seed * 20.0);
	float star = step(0.994, star_seed) * (1.0 - smoothstep(0.018, 0.09, length(local))) * twinkle;
	color += vec3(0.60, 0.78, 1.0) * star * 0.82;

	float vignette = 1.0 - smoothstep(0.24, 0.92, length((uv - 0.5) * vec2(0.88, 0.82)));
	color *= 0.72 + vignette * 0.28;
	COLOR = vec4(color, 1.0);
}