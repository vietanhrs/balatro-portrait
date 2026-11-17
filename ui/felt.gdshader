shader_type canvas_item;
uniform float motion = 1.0;
void fragment() {
 vec2 uv = UV;
 float t = TIME * 0.018 * motion;
 vec4 a = texture(TEXTURE, fract(uv + vec2(t, -t * 0.5)));
 vec4 b = texture(TEXTURE, fract(uv * 1.16 + vec2(-t * 0.4, t * 0.6)));
 COLOR = vec4(mix(a.rgb, b.rgb, 0.28), 1.0);
}
