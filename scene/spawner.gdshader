shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture; 
uniform float curvature : hint_range(0.0, 5.0) = 0.5; 
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2; 
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3; 
uniform vec2 resolution = vec2(0.0); 
uniform float pixel_size : hint_range(1.0, 20.0) = 2.0; 
uniform float zoom : hint_range(1.0, 5) = 4.2;
void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5, 0.5);
    vec2 offset = (uv - center) * (1.0 / zoom);
    float dist = length(offset);
    uv = center + offset + offset * dist * dist * curvature;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        discard;
    }
    vec2 current_res = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 target_res = (resolution.x > 0.0 && resolution.y > 0.0) ? resolution : current_res;
    if (pixel_size > 1.0) {
        vec2 grid_size = target_res / pixel_size;
        uv = floor(uv * grid_size) / grid_size;
    }
    vec3 color = texture(screen_texture, uv).rgb;
    float scanline = abs(sin(uv.y * target_res.y * 2.0)) * scanline_intensity;
    color += scanline * 0.1; 
    float vignette = smoothstep(0.8, 0.2, dist) * vignette_strength;
    color += vec3(vignette * 0.1); 
    COLOR = vec4(color, 1.0);
}
