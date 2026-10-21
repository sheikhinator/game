shader_type spatial;
// Skin plus painted-on clothing. Vertex COLOR holds the clothing masks:
// r = shirt, g = trousers, b = shoes (computed from the rest pose at load time).

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 rough_channel = vec4(0.0, 1.0, 0.0, 0.0);

uniform sampler2D shirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pants_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pants_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shoe_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shoe_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 shirt_color : source_color = vec4(0.2, 0.25, 0.35, 1.0);
uniform vec4 pants_color : source_color = vec4(0.35, 0.42, 0.55, 1.0);
uniform vec4 shoe_color : source_color = vec4(0.92, 0.92, 0.9, 1.0);
uniform float fabric_scale = 9.0;

void fragment() {
	vec4 m = COLOR;
	float shirt = m.r;
	float pants = m.g;
	float shoes = m.b;
	vec2 fuv = UV * fabric_scale;

	vec3 skin = texture(skin_albedo, UV).rgb;
	vec3 sh = texture(shirt_albedo, fuv).rgb;
	vec3 pa = texture(pants_albedo, fuv * 0.8).rgb;
	vec3 so = texture(shoe_albedo, fuv * 1.4).rgb;

	// Desaturate fabric photos so the chosen colour reads cleanly.
	float shl = dot(sh, vec3(0.333));
	float pal = dot(pa, vec3(0.333));
	float sol = dot(so, vec3(0.333));
	vec3 col = skin;
	col = mix(col, shirt_color.rgb * (0.55 + shl * 0.9), shirt);
	col = mix(col, pants_color.rgb * (0.45 + pal * 1.1), pants);
	col = mix(col, shoe_color.rgb * (0.6 + sol * 0.6), shoes);
	ALBEDO = col;

	float r_skin = dot(texture(skin_rough, UV), rough_channel);
	ROUGHNESS = mix(r_skin, 0.92, clamp(shirt + pants, 0.0, 1.0));
	ROUGHNESS = mix(ROUGHNESS, 0.55, shoes);
	SPECULAR = mix(0.5, 0.25, clamp(shirt + pants, 0.0, 1.0));

	vec3 n = texture(skin_normal, UV).rgb;
	n = mix(n, texture(shirt_normal, fuv).rgb, shirt);
	n = mix(n, texture(pants_normal, fuv * 0.8).rgb, pants);
	n = mix(n, texture(shoe_normal, fuv * 1.4).rgb, shoes);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.0;
}
