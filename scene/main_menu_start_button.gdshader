shader_type canvas_item;

// Эта переменная будет отвечать за размер пикселей (1.0 - нормальный вид)
uniform float pixel_size : hint_range(1.0, 100.0) = 1.0;

void fragment() {
    // Если размер пикселя равен 1, оставляем текстуру как есть
    if (pixel_size > 1.0) {
        vec2 size = vec2(textureSize(TEXTURE, 0));
        // Вычисляем новые "грубые" координаты
        vec2 uv = floor(UV * size / pixel_size) * pixel_size / size;
        COLOR = texture(TEXTURE, uv);
    } else {
        COLOR = texture(TEXTURE, UV);
    }
}
