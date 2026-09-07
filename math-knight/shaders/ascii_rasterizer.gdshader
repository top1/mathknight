shader_type canvas_item;

// ═══════════════════════════════════════════════════════════════════════════
// ASCII Rasterizer Shader — Cyber-Math Character Matrix for Math Knight
// Converts a 3D SubViewport render into stylized glowing ASCII characters.
// ═══════════════════════════════════════════════════════════════════════════

uniform sampler2D char_atlas : filter_nearest;
uniform int num_chars : hint_range(1, 32) = 16;
uniform vec2 cell_size = vec2(6.0, 8.0);
uniform float brightness_mult : hint_range(0.5, 3.0) = 1.35;
uniform float edge_strength : hint_range(0.0, 3.0) = 1.5;
uniform float min_alpha_cutoff : hint_range(0.0, 0.5) = 0.04;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.10;
uniform vec4 glow_color : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform float bloom_leak : hint_range(0.0, 0.4) = 0.08;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));

	if (tex_size.x < 1.0 || tex_size.y < 1.0) {
		COLOR = vec4(0.0);
	} else {
		// 1. Pixel coordinate in texture space
		vec2 pixel_pos = UV * tex_size;

		// 2. Cell coordinate & local character UV (0.0 to 1.0 inside cell)
		vec2 cell_coord = floor(pixel_pos / cell_size);
		vec2 char_uv = fract(pixel_pos / cell_size);

		// 3. Center UV of this cell in normalized texture coordinates
		vec2 cell_center_uv = (cell_coord * cell_size + cell_size * 0.5) / tex_size;
		cell_center_uv = clamp(cell_center_uv, vec2(0.001), vec2(0.999));

		// 4. Sample the central cell color & alpha
		vec4 cell_col = texture(TEXTURE, cell_center_uv);

		if (cell_col.a < min_alpha_cutoff) {
			COLOR = vec4(0.0);
		} else {
			// 5. Sobel Edge Detection around cell center for crisp outlines
			vec2 offset = cell_size / tex_size;
			float l_left   = dot(texture(TEXTURE, cell_center_uv - vec2(offset.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
			float l_right  = dot(texture(TEXTURE, cell_center_uv + vec2(offset.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
			float l_up     = dot(texture(TEXTURE, cell_center_uv - vec2(0.0, offset.y)).rgb, vec3(0.299, 0.587, 0.114));
			float l_down   = dot(texture(TEXTURE, cell_center_uv + vec2(0.0, offset.y)).rgb, vec3(0.299, 0.587, 0.114));
			float edge = (abs(l_right - l_left) + abs(l_down - l_up)) * edge_strength;

			// 6. Cell Luminance calculation
			float lum = dot(cell_col.rgb, vec3(0.299, 0.587, 0.114));
			float intensity = clamp(lum + edge * 0.45, 0.0, 1.0);

			// 7. Select character index in atlas (0 = space/faintest, num_chars-1 = densest)
			int char_idx = clamp(int(floor(intensity * float(num_chars))), 0, num_chars - 1);

			// Ensure visible edge chars if edge is strong even at lower luminance
			if (edge > 0.35 && char_idx < 4) {
				char_idx = 4;
			}

			// 8. Sample character glyph from the horizontal atlas
			float u_start = float(char_idx) / float(num_chars);
			float u_width = 1.0 / float(num_chars);
			vec2 glyph_uv = vec2(u_start + char_uv.x * u_width, char_uv.y);
			vec4 glyph_sample = texture(char_atlas, glyph_uv);
			float glyph_alpha = glyph_sample.r; // Glyph grayscale/red mask

			// 9. Cyber scanline modulation
			float scanline = 1.0 - scanline_strength * sin(pixel_pos.y * 3.14159265);

			// 10. Blend character with cell color and emissive glow
			vec3 final_rgb = cell_col.rgb * glyph_alpha * brightness_mult * scanline;

			// Add ambient bloom / fill so letters stand out on dark areas
			final_rgb += cell_col.rgb * bloom_leak * cell_col.a;

			float final_a = clamp(glyph_alpha * cell_col.a * 1.5 + bloom_leak * cell_col.a, 0.0, 1.0);

			COLOR = vec4(final_rgb, final_a);
		}
	}
}
