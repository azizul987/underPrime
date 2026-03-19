shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 internal_res = vec2(640.0, 360.0);

// --- Gelombang ---
uniform float wave_speed    = 1.2;
uniform float wave_freq     = 0.18;
uniform float wave_width    = 2.0;
uniform float wave2_strength = 0.5;
uniform float wave2_speed   = 0.7;
uniform float wave2_freq    = 0.11;

// --- Warna air ---
uniform vec4  water_color : source_color = vec4(0.05, 0.30, 0.60, 0.32);
uniform vec4  deep_color  : source_color = vec4(0.02, 0.15, 0.40, 0.55);
uniform float water_height = 360.0;   // baris pixel Y dimana air mulai (dari atas)

// --- Efek permukaan ---
uniform float highlight_strength = 0.14;
uniform float shadow_strength    = 0.08;
uniform float foam_threshold     = 0.72;   // ambang busa (0.0-1.0, makin kecil makin banyak busa)
uniform float foam_brightness    = 0.55;

// --- Caustic / shimmer ---
uniform float caustic_strength   = 0.06;
uniform float caustic_speed      = 2.3;
uniform float caustic_scale      = 0.07;

// --- Parallax ---
uniform float parallax_depth     = 0.35;   // seberapa kuat efek parallax depth

void fragment() {
    vec2 pixel   = floor(SCREEN_UV * internal_res);
    float t      = TIME;
    float y      = pixel.y;
    float x      = pixel.x;

    // Depth factor: 0.0 di permukaan, 1.0 di bawah
    float depth  = clamp((y - water_height) / (internal_res.y - water_height), 0.0, 1.0);

    // Parallax: layer bawah bergerak lebih lambat
    float speed_scale = 1.0 - depth * parallax_depth;

    // Gelombang utama dan kedua
    float wave1  = sin(t * wave_speed * speed_scale + y * wave_freq + x * 0.012);
    float wave2  = sin(t * wave2_speed * speed_scale + y * wave2_freq + x * 0.008 + 1.7);
    float wave   = wave1 + wave2 * wave2_strength;

    // Offset horizontal, pixel-snapped
    float offset_px = round(wave * wave_width * (1.0 - depth * 0.5));
    vec2 sample_px  = vec2(clamp(pixel.x + offset_px, 0.0, internal_res.x - 1.0), pixel.y);
    vec2 final_uv   = sample_px / internal_res;

    // Ambil background
    vec4 bg = texture(screen_texture, final_uv);

    // --- Tint air: blend antara water_color (permukaan) dan deep_color (dalam) ---
    vec4 w_color = mix(water_color, deep_color, depth);
    vec3 tinted  = mix(bg.rgb, w_color.rgb, w_color.a);

    // --- Surface normal fake dari turunan gelombang ---
    // Approx turunan dwave/dy untuk highlight/shadow
    float wave1_dy = cos(t * wave_speed * speed_scale + y * wave_freq + x * 0.012) * wave_freq;
    float light    = clamp( wave1_dy, 0.0, 1.0) * highlight_strength * (1.0 - depth * 0.6);
    float dark     = clamp(-wave1_dy, 0.0, 1.0) * shadow_strength    * (1.0 - depth * 0.6);
    tinted += light;
    tinted -= dark;

    // --- Caustic shimmer (hanya di dekat permukaan) ---
    float caustic_fade = 1.0 - smoothstep(0.0, 0.45, depth);
    float ca = sin(t * caustic_speed       + x * caustic_scale        + y * caustic_scale * 0.7);
    float cb = sin(t * caustic_speed * 0.6 + x * caustic_scale * 1.3  + y * caustic_scale * 0.4 + 2.1);
    float cc = sin(t * caustic_speed * 1.4 + x * caustic_scale * 0.8  + y * caustic_scale * 1.1 + 4.3);
    // Pixel-snap caustic: floor ke nilai kasar supaya tetap blocky
    float caustic_raw = (ca + cb + cc) / 3.0;
    float caustic_px  = floor(caustic_raw * 4.0) / 4.0;  // kuantisasi 4 level
    tinted += max(caustic_px, 0.0) * caustic_strength * caustic_fade;

    // --- Foam / busa di puncak ombak ---
    // Normalized wave value (0.0-1.0)
    float wave_norm = (wave / (1.0 + wave2_strength));          // range ~-1..1
    float wave_01   = wave_norm * 0.5 + 0.5;                   // remap ke 0..1
    float foam_fade = 1.0 - smoothstep(0.0, 0.3, depth);       // hanya di permukaan atas
    float foam      = step(foam_threshold, wave_01) * foam_fade;
    // Pixel-snap foam: hanya muncul di beberapa pixel horizontal supaya dotty
    float foam_dot  = step(0.5, fract(x * 0.5));               // selang-seling kolom
    tinted = mix(tinted, vec3(foam_brightness), foam * foam_dot);

    COLOR = vec4(tinted, bg.a);
}