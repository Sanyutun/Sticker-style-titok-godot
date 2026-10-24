shader_type canvas_item;
render_mode blend_mix, unshaded;

// Alpha-aware silhouette outline + shadow. The outline is sampled from the
// texture alpha, so it follows transparent cutouts rather than the sprite rect.
// Sampling is inlined in fragment(): Godot 4 shader helper functions cannot
// reference the TEXTURE built-in, and passing it as a sampler argument trips a
// GLES3 compiler edge case.
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.10, 0.16, 0.20, 0.20);
uniform vec2 outline_uv = vec2(0.012, 0.012);
uniform vec2 shadow_offset_uv = vec2(0.0, -0.014);
uniform float shadow_softness = 1.0;
uniform float outline_enabled = 1.0;
uniform float shadow_enabled = 1.0;
uniform float alpha_threshold = 0.18;

const int SAMPLES = 14;

bool inside_uv(vec2 p) {
	return p.x >= 0.0 && p.y >= 0.0 && p.x <= 1.0 && p.y <= 1.0;
}

void fragment() {
	vec2 uv = UV;
	vec4 src = texture(TEXTURE, uv);

	// Shadow is sampled from an offset copy of the alpha silhouette.
	float shadow_a = 0.0;
	if (shadow_enabled > 0.5) {
		vec2 suv = uv + shadow_offset_uv;
		vec2 srad = outline_uv * (0.85 + shadow_softness * 0.28);
		for (int layer = 0; layer < 2; layer++) {
			float mul = layer == 0 ? 1.0 : 1.55;
			float weight = layer == 0 ? 1.0 : 0.30;
			for (int i = 0; i < SAMPLES; i++) {
				float ang = (float(i) + 0.5) * 6.2831853 / float(SAMPLES);
				vec2 p = suv + vec2(cos(ang), sin(ang)) * srad * mul;
				if (inside_uv(p)) {
					shadow_a = max(shadow_a, texture(TEXTURE, p).a * weight);
				}
			}
		}
		if (inside_uv(suv)) {
			shadow_a = max(shadow_a, texture(TEXTURE, suv).a * 0.55);
		}
	}

	float outline_a = 0.0;
	if (outline_enabled > 0.5) {
		for (int i = 0; i < SAMPLES; i++) {
			float ang = (float(i) + 0.5) * 6.2831853 / float(SAMPLES);
			vec2 p = uv + vec2(cos(ang), sin(ang)) * outline_uv;
			if (inside_uv(p)) {
				outline_a = max(outline_a, texture(TEXTURE, p).a);
			}
		}
	}

	vec3 rgb = shadow_color.rgb;
	float a = shadow_a * shadow_color.a;
	float ring = smoothstep(alpha_threshold, alpha_threshold + 0.22, outline_a) * (1.0 - smoothstep(0.04, 0.32, src.a));
	rgb = mix(rgb, outline_color.rgb, ring);
	a = max(a, ring * outline_color.a);
	// Source image is composited on top of outline + shadow.
	rgb = mix(rgb, src.rgb, src.a);
	a = max(a, src.a);
	COLOR = vec4(rgb, a);
}
