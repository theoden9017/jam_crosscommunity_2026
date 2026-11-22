
shader_type canvas_item;
render_mode unshaded;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_frequency : hint_range(50.0, 500.0) = 220.0;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec2 uv = UV;

    // Scanlines orizzontali
    float scanline = sin(
        uv.y * scanline_frequency
        - TIME * animation_speed
    );

    scanline = smoothstep(-0.2, 0.8, scanline);

    // Leggera vignettatura
    float vignette = uv.x * (1.0 - uv.x)
                   * uv.y * (1.0 - uv.y);

    vignette = clamp(vignette * 16.0, 0.0, 1.0);

    // Glow leggermente pulsante
    float pulse = 0.5 + 0.5 * sin(TIME * 1.5);

    float alpha = scanline_strength * (1.0 - scanline);
    alpha += glow_strength * pulse * 0.12;
    alpha += (1.0 - vignette) * 0.025;

    COLOR = vec4(0.35, 0.65, 0.85, alpha);
}
