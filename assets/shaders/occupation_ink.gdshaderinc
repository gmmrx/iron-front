// Cartographic ink, shared by the front band and the existing occupied-state fill.
// World coordinates anchor the marks; pixel footprint only filters them, never rescales their phase.
float war_ink_integral(float phase, float duty) {
	return floor(phase) * duty + min(fract(phase), duty);
}

float war_ink_stroke(float phase, float duty, float footprint) {
	float width = clamp(duty, 0.0, 0.45);
	float filter_width = max(footprint, 0.0001);
	float center = fract(phase) + width * 0.5; // Keep integral subtraction precise at large world coordinates.
	return clamp((war_ink_integral(center + filter_width * 0.5, width)
		- war_ink_integral(center - filter_width * 0.5, width)) / filter_width, 0.0, 1.0);
}

float occupation_ink(vec2 world_position, float world_footprint) {
	const float spacing = 4.8;
	const float line_width = 0.56;
	float phase = dot(world_position, vec2(0.70710678, 0.70710678)) / spacing;
	return war_ink_stroke(phase, line_width / spacing, world_footprint / spacing);
}
