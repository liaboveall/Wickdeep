shader_type canvas_item;
// Red screen-edge vignette: flashes when the player is hurt, pulses at low health.

uniform float strength = 0.0;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.25, 0.75, length(d * vec2(1.0, 0.75)) * 1.3);
	COLOR = vec4(0.75, 0.08, 0.1, v * strength);
}
