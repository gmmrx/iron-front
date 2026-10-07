// Low-resolution persistent discovery mask. No cloud volume or 3D noise is part of this pass.
export const maskVertex = /* glsl */`
out vec2 vUv;
void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }
`;
export const maskFragment = /* glsl */`
precision highp float;
precision highp int;
in vec2 vUv;
out vec4 outColor;
uniform sampler2D provTex;
uniform sampler2D fogTex;
uniform vec2 worldSize;
void main() {
  vec2 sz = vec2(textureSize(provTex, 0));
  float sum = 0.0;
  for (int y = 0; y < 4; y++) for (int x = 0; x < 4; x++) {
    vec2 p = vUv * worldSize + (vec2(float(x), float(y)) / 3.0 - 0.5) * 3.0;
    vec2 uv = vec2(p.x / worldSize.x, 1.0 - p.y / worldSize.y);
    vec4 c = texelFetch(provTex, ivec2(clamp(uv * sz, vec2(0), sz - 1.0)), 0);
    int id = int(round(c.r * 255.0)) + int(round(c.g * 255.0)) * 256;
    if (id > 0) sum += 1.0 - texelFetch(fogTex, ivec2(id % 256, id / 256), 0).r;
  }
  outColor = vec4(sum / 16.0, 0, 0, 1);
}`;
