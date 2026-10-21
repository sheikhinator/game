shader_type sky;
// Lycho sky: physically-flavoured gradient, sun disc with glow, stars at night,
// and drifting layered clouds. Colours are driven by DayNight.

uniform vec3 top_color : source_color = vec3(0.24, 0.45, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.78, 0.9);
uniform vec3 ground_color : source_color = vec3(0.2, 0.2, 0.21);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.95, 0.85);
uniform float day = 1.0;              // 0 night .. 1 day
uniform float cloud_cover = 0.55;
uniform float cloud_time = 0.0;
uniform float energy = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.45));
	col = mix(col, ground_color, smoothstep(0.0, -0.08, h));

	// Sun.
	vec3 sd = LIGHT0_DIRECTION;
	float sun_dot = max(dot(dir, sd), 0.0);
	if (LIGHT0_ENABLED) {
		col += sun_tint * pow(sun_dot, 900.0) * 18.0 * day;
		col += sun_tint * pow(sun_dot, 12.0) * 0.28 * day;
		col += sun_tint * pow(sun_dot, 3.0) * 0.08 * day * (1.0 - clamp(h * 2.0, 0.0, 1.0));
	}

	// Stars.
	if (day < 0.6 && h > 0.0) {
		vec2 sp = dir.xz / (dir.y + 0.3) * 160.0;
		float st = step(0.9965, hash(floor(sp))) * (1.0 - day / 0.6) * smoothstep(0.0, 0.3, h);
		col += vec3(st) * 0.9;
	}

	// Clouds on a flat layer projected onto the dome.
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * 1.6 + vec2(cloud_time * 0.01, cloud_time * 0.004);
		float n = fbm(uv);
		float detail = fbm(uv * 3.1 + 7.0);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, n * 0.75 + detail * 0.35);
		c *= smoothstep(0.0, 0.05, h);
		float lit = 0.55 + 0.45 * pow(sun_dot, 4.0);
		vec3 cloud_col = mix(vec3(0.05, 0.06, 0.08), vec3(0.97, 0.97, 0.98), day);
		cloud_col = mix(cloud_col, cloud_col * vec3(0.62, 0.66, 0.74), smoothstep(0.55, 0.95, n));
		cloud_col *= mix(0.75, 1.15, detail) * lit;
		cloud_col += sun_tint * pow(sun_dot, 6.0) * 0.6 * day;
		col = mix(col, cloud_col, c * 0.92);
	}
	COLOR = col * energy;
}
