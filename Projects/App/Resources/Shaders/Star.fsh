// Star.fsh — GPU 영롱한 별 프래그먼트 셰이더
// 별마다 고유한 스파이크 각도, 비대칭 글로우, 색수차

void main() {
    vec2 uv = v_tex_coord - 0.5;
    float r = length(uv) * 2.0;
    float angle = atan(uv.y, uv.x);

    // ── 원형 마스크 ──
    float edgeMask = 1.0 - smoothstep(0.7, 1.0, r);

    // ── 별마다 고유 시드 (색상 기반) ──
    float seed = fract(a_color.r * 7.3 + a_color.g * 13.7 + a_color.b * 23.1);

    // ── 1. 코어 ──
    float core = exp(-r * r * 80.0);

    // ── 2. 내부 글로우 — 비대칭 (별마다 다른 타원 방향) ──
    float ovalDir = seed * 6.2832;
    float ovalStretch = 1.0 + 0.2 * cos(angle * 2.0 - ovalDir);
    float innerGlow = exp(-r * r * 12.0 * ovalStretch) * 0.6;

    // ── 3. 외부 헤일로 — 불규칙한 가장자리 ──
    float haloWarp = 1.0 + 0.15 * sin(angle * 3.0 + seed * 4.7);
    float outerHalo = exp(-r * 3.0 * haloWarp) * 0.14;

    // ── 4. 회절 스파이크 — 별마다 회전, 더 뚜렷 ──
    float spikeRot = seed * 3.14159 + u_time * 0.04;
    float cs = cos(spikeRot);
    float sn = sin(spikeRot);
    vec2 rotUV = vec2(uv.x * cs - uv.y * sn, uv.x * sn + uv.y * cs);

    float spike1 = exp(-abs(rotUV.y) * 28.0) * exp(-r * 4.0);
    float spike2 = exp(-abs(rotUV.x) * 28.0) * exp(-r * 4.0);
    float d1 = abs(rotUV.x + rotUV.y) / 1.414;
    float d2 = abs(rotUV.x - rotUV.y) / 1.414;
    float diag1 = exp(-d1 * 35.0) * exp(-r * 5.0) * 0.35;
    float diag2 = exp(-d2 * 35.0) * exp(-r * 5.0) * 0.35;
    float spikes = (spike1 + spike2) * 0.5 + diag1 + diag2;

    // ── 5. 에어리 디스크 ──
    float rings = max(sin(r * 50.0) * exp(-r * 10.0) * 0.03, 0.0);

    // ── 6. 색수차 ──
    vec3 starColor = a_color.rgb;
    vec3 chromatic = vec3(
        exp(-r * r * 10.0) * 0.06,
        0.0,
        exp(-(r - 0.02) * (r - 0.02) * 10.0) * 0.05
    );

    // ── 7. 반짝임 — 별마다 다른 속도 ──
    float twinkle = 0.85 + 0.15 * sin(u_time * (2.0 + seed * 1.5) + angle * 3.0);

    // ── 합산 ──
    float brightness = (core + innerGlow + outerHalo + spikes + rings) * twinkle * edgeMask;

    vec3 col = mix(starColor, vec3(1.0), core * 0.8 + innerGlow * 0.3);
    col = (col + chromatic) * brightness;

    gl_FragColor = vec4(col, brightness) * v_color_mix;
}
