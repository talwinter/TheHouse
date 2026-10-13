shader_type canvas_item;
// Screen overlay: soft vignette + fine animated film grain (both adjustable / off).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.45;
uniform float grain = 0.035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 d = SCREEN_UV - vec2(0.5);
	d.x *= 1.25;
	float v = smoothstep(0.32, 0.86, length(d));
	c *= 1.0 - v * vignette;
	float n = hash(floor(FRAGCOORD.xy) + vec2(fract(TIME * 7.0) * 113.0, fract(TIME * 3.0) * 71.0));
	c += (n - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
