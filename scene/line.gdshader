shader_type canvas_item; 
render_mode unshaded; 

uniform vec4 color_1 : source_color = vec4(0.0, 1.0, 0.9, 1.0); 
uniform vec4 color_2 : source_color = vec4(0.5, 0.0, 1.0, 1.0); 
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 2.0; 
uniform float speed_forward = -2.0; 
uniform float speed_backward = 1.5; 
uniform float noise_scale = 0.05; 
uniform float pulse_speed = 3.0; 
uniform float break_intensity : hint_range(0.0, 1.0) = 0.4; 
uniform float break_scale = 0.05; 
uniform float break_speed = 2.5; 

vec2 hash( vec2 p ) { 
    p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) ); 
    return -1.0 + 2.0*fract(sin(p)*43758.5453123); 
} 

float noise( in vec2 p ) { 
    const float K1 = 0.366025404; 
    const float K2 = 0.211324865; 
    vec2 i = floor( p + (p.x+p.y)*K1 ); 
    vec2 a = p - i + (i.x+i.y)*K2; 
    float m = step(a.y,a.x); 
    vec2 o = vec2(m,1.0-m); 
    vec2 b = a - o + K2; 
    vec2 c = a - 1.0 + 2.0*K2; 
    vec3 h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 ); 
    vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0))); 
    return dot( n, vec3(70.0) ) * 0.5 + 0.5; 
} 

void fragment() { 
    vec2 screen_res = 1.0 / SCREEN_PIXEL_SIZE; 
    vec2 current_pixel = SCREEN_UV * screen_res; 
    vec2 uv = floor(current_pixel / pixel_size) * pixel_size; 
    float noise_forward = noise(vec2(uv.x * noise_scale, uv.y * noise_scale - TIME * speed_forward)); 
    float noise_backward = noise(vec2(uv.x * noise_scale, uv.y * noise_scale - TIME * speed_backward)); 
    float final_noise = (noise_forward + noise_backward) * 0.5; 
    float color_mask = step(0.5, final_noise); 
    vec4 final_color = mix(color_1, color_2, color_mask); 
    float break_noise = noise(vec2(uv.x * break_scale, uv.y * break_scale + TIME * break_speed)); 
    float break_mask = step(break_intensity, break_noise); 

    float pulse = step(0.3, sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.3 + 0.7; 

    COLOR = final_color; 
    COLOR.a *= pulse * break_mask; 
}
