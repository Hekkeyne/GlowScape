shader_type canvas_item;

// Порог, где начинается кольцо
uniform float threshold : hint_range(0.0, 1.0) = 0.4;
// Толщина линии кольца
uniform float thickness : hint_range(0.0, 0.5) = 0.05;
// Сглаживание краев кольца
uniform float softness : hint_range(0.0, 0.1) = 0.01;

uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float alpha = tex_color.a;
    
    // Создаем внешнюю границу кольца
    float outer_edge = smoothstep(threshold - softness, threshold + softness, alpha);
    
    // Создаем внутреннюю границу кольца (сдвинутую на толщину thickness)
    float inner_edge = smoothstep(threshold + thickness - softness, threshold + thickness + softness, alpha);
    
    // Вычитаем внутреннюю часть из внешней, чтобы получить пустое кольцо
    float ring_mask = outer_edge - inner_edge;
    
    // Выводим цвет кольца с нашей маской прозрачности
    COLOR = vec4(ring_color.rgb, ring_mask);
}
