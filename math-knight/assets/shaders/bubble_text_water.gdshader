shader_type canvas_item;

uniform float shine_speed : hint_range(0.2, 4.0) = 1.8;
uniform float shine_intensity : hint_range(0.0, 1.0) = 0.28;
uniform vec4 text_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.01) {
		// Smooth diagonal light sheen across the number (keeps geometry 100% sharp)
		float gleam = sin((UV.x * 4.0) + (UV.y * 4.0) - TIME * shine_speed);
		float highlight = max(0.0, gleam) * shine_intensity;
		
		vec3 col = (tex.rgb * text_tint.rgb) + vec3(highlight);
		COLOR = vec4(col, tex.a);
	} else {
		COLOR = tex;
	}
}
