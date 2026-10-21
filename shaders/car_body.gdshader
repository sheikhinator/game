shader_type spatial;
// Car body: paint, tinted glass, black trims, door seams and handles, all computed
// per pixel from the car's own profile so every edge is clean.
// Mesh-local axes (from the generator): +X forward, +Y up, -Z = car's left.

uniform sampler2D profile : filter_linear, repeat_disable; // R = belt line, G = roof (metres)
uniform float car_length = 4.75;
uniform float car_width = 1.84;
uniform float clearance = 0.16;
uniform float wheel_r = 0.33;
uniform float axle_front = 1.4;
uniform float axle_rear = -1.4;
uniform float cabin_start = 0.2;
uniform float cabin_end = 0.76;
uniform float roof_max = 1.45;
uniform vec4 paint : source_color = vec4(0.55, 0.57, 0.6, 1.0);
uniform float paint_metallic = 0.6;
uniform float paint_rough = 0.26;
uniform float dirt = 0.15;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float band(float x, float a, float b, float soft) {
	return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x));
}

void fragment() {
	float f = clamp((lp.x + car_length * 0.5) / car_length, 0.0, 1.0);
	vec2 pr = texture(profile, vec2(f, 0.5)).rg;
	float belt = pr.r;
	float roof = pr.g;
	float z = lp.y;
	float side = smoothstep(0.35, 0.6, abs(ln.z));
	float up = smoothstep(0.75, 0.92, abs(ln.y));
	float aa = fwidth(z) * 1.5 + 0.002;

	float x_cs = -car_length * 0.5 + cabin_start * car_length;
	float x_ce = -car_length * 0.5 + cabin_end * car_length;
	float in_cabin = band(lp.x, x_cs + 0.06, x_ce - 0.06, 0.01);
	float flat_top = smoothstep(0.965, 0.99, abs(ln.y));
	// Side windows stop under the roof line; sloped screens run up to the roof edge.
	float top = mix(roof_max, roof, side);
	float glass = in_cabin * band(z, belt + 0.04, top - 0.045, aa) * (1.0 - flat_top);
	float frame = in_cabin * band(z, belt + 0.02, top - 0.025, aa) * (1.0 - flat_top) * (1.0 - glass);

	// Pillars: B pillar on the sides, painted black like most modern cars.
	float x_mid = mix(x_cs, x_ce, 0.48);
	float bpillar = glass * side * (1.0 - smoothstep(0.035, 0.04, abs(lp.x - x_mid)));
	glass -= bpillar;

	// Lower trim and wheel-arch liners.
	float sill = 1.0 - smoothstep(clearance + 0.1, clearance + 0.12, z);
	float arch = 0.0;
	for (int i = 0; i < 2; i++) {
		float ax = i == 0 ? axle_front : axle_rear;
		float d = length(vec2(lp.x - ax, z - wheel_r));
		arch = max(arch, (1.0 - smoothstep(wheel_r + 0.075, wheel_r + 0.095, d)) * (1.0 - side * 0.0));
	}
	float trim = clamp(max(max(sill, arch), max(frame, bpillar)), 0.0, 1.0);

	// Door seams and handles on the flanks.
	float seam = 0.0;
	float x_d0 = axle_front - wheel_r - 0.14;
	float x_d2 = axle_rear + wheel_r + 0.12;
	float lw = 0.0035;
	float body_side = side * band(z, clearance + 0.14, belt - 0.005, 0.004);
	seam += body_side * (1.0 - smoothstep(lw, lw * 2.0, abs(lp.x - x_d0)));
	seam += body_side * (1.0 - smoothstep(lw, lw * 2.0, abs(lp.x - x_mid)));
	seam += body_side * (1.0 - smoothstep(lw, lw * 2.0, abs(lp.x - x_d2)));
	float handle = side * band(z, belt - 0.085, belt - 0.06, 0.003) * (band(lp.x, x_mid - 0.26, x_mid - 0.1, 0.003) + band(lp.x, x_d2 - 0.26, x_d2 - 0.1, 0.003));
	// Shut line across the bonnet and boot lid.
	float x_hood = x_ce + 0.02;
	float lid = up * (1.0 - smoothstep(lw, lw * 2.0, abs(lp.x - x_hood)));
	seam = clamp(seam + lid, 0.0, 1.0);

	vec3 paint_col = paint.rgb * mix(1.0, 0.82, dirt * (1.0 - smoothstep(clearance, clearance + 0.5, z)));
	vec3 col = paint_col;
	float metal = paint_metallic;
	float rough = paint_rough;
	col = mix(col, vec3(0.012, 0.012, 0.014), trim);
	metal = mix(metal, 0.0, trim);
	rough = mix(rough, 0.6, trim);
	col = mix(col, vec3(0.008, 0.01, 0.012), glass);
	metal = mix(metal, 0.1, glass);
	rough = mix(rough, 0.03, glass);
	col = mix(col, col * 0.18, clamp(seam, 0.0, 1.0));
	col = mix(col, vec3(0.04), clamp(handle, 0.0, 1.0) * 0.8);
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = mix(0.5, 0.9, glass);
	CLEARCOAT = (1.0 - trim) * (1.0 - glass);
	CLEARCOAT_ROUGHNESS = 0.04;
}
