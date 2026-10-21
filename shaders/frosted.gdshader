shader_type canvas_item;
// Frosted glass: blurred screen behind the control, tinted and vignetted.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.02, 0.025, 0.035, 0.72);
uniform float blur = 3.5;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	c = mix(c, tint.rgb, tint.a);
	float v = smoothstep(1.25, 0.35, length(SCREEN_UV - vec2(0.5)) * 1.4);
	COLOR = vec4(c * mix(0.7, 1.0, v), 1.0);
}
