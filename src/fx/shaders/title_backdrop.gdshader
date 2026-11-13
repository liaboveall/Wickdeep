shader_type canvas_item;
// Title screen backdrop: a warm glow rising from the bottom edge, with a little pixel grain.

void fragment() {
	vec2 uv = UV;
	float glow = 1.0 - smoothstep(0.0, 0.75, distance(uv, vec2(0.5, 0.95)));
	vec3 base = mix(vec3(0.05, 0.035, 0.08), vec3(0.16, 0.08, 0.07), glow);
	float n = fract(sin(dot(floor(uv * vec2(320.0, 180.0)), vec2(12.9898, 78.233))) * 43758.5453);
	base += (n - 0.5) * 0.012;
	COLOR = vec4(base, 1.0);
}
