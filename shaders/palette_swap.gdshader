shader_type canvas_item;
uniform sampler2D palette;
void fragment() {
	COLOR = texture(TEXTURE, UV);
}
