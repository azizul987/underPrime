
shader_type canvas_item;

// Kecepatan gelombang air
uniform float wave_speed = 2.0;
// Kerapatan gelombang (semakin besar angkanya, riaknya semakin banyak)
uniform float wave_freq = 10.0;
// Jarak goyangan DALAM SATUAN PIXEL (sangat gampang diaturnya sekarang)
uniform float wave_amplitude = 2.0; 

void fragment() {
	vec2 distorted_uv = UV;
	
	// 1. Hitung nilai gelombang murni (nilainya naik turun antara -1.0 dan 1.0)
	float wave = sin(TIME * wave_speed + UV.y * wave_freq);
	
	// 2. Kunci rahasia Pixel Art: Kalikan dengan amplitudo, lalu BULATKAN (round).
	// Ini memaksa pergeseran hanya terjadi sejauh 1, 2, atau 3 pixel secara utuh, tidak ada koma.
	float pixel_offset = round(wave * wave_amplitude);
	
	// 3. Aplikasikan pergeseran ke UV X. 
	// TEXTURE_PIXEL_SIZE.x adalah ukuran tepat 1 pixel dari teksturmu.
	distorted_uv.x += pixel_offset * TEXTURE_PIXEL_SIZE.x;
	
	// Terapkan warna
	COLOR = texture(TEXTURE, distorted_uv);
}