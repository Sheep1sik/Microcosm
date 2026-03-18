// Galaxy.fsh — GPU 나선 은하 프래그먼트 셰이더 + 중심핵
// SKShader용 GLSL ES 2.0

void main() {
    vec2 uv = v_tex_coord - 0.5;

    // ellipticity
    uv.y /= max(a_ellipticity, 0.15);

    float r = length(uv) * 2.0;
    float angle = atan(uv.y, uv.x);

    // ── 나선팔 (부드럽고 은은하게) ──
    float spiral = angle + a_wind * log(r + 0.001) + u_time * 0.08;
    float armPattern = cos(spiral * a_arm_count);
    // 팔을 부드럽게: 최대 0.35, 팔 사이 0.1
    float arm = smoothstep(-0.3, 1.0, armPattern) * 0.25 + 0.1;

    // 방사형 감쇠 — 더 넓고 부드럽게
    float falloff = 1.0 - smoothstep(0.0, 0.55, r);
    falloff *= falloff;

    // ── 중심핵 (은은하게) ──
    float coreHot = exp(-r * r * 120.0) * 0.6;    // 밝은 점 (절제)
    float bulge = exp(-r * r * 12.0) * 0.4;       // 넓은 벌지
    float coreGlow = exp(-r * r * 4.0) * 0.25;    // 은은한 글로우

    // ── 밀도: 코어가 지배적, 팔은 보조 ──
    float density = arm * falloff + coreHot + bulge + coreGlow;

    // ── 색상 ──
    vec3 galaxyColor = a_color.rgb;
    vec3 whiteCore = vec3(1.0, 0.98, 0.95);
    vec3 brightBulge = min(galaxyColor + vec3(0.3), vec3(1.0));

    // 기본색은 은하색, 벌지 영역은 밝게, 코어는 화이트
    vec3 col = galaxyColor;
    col = mix(col, brightBulge, bulge + coreGlow * 0.4);
    col = mix(col, whiteCore, coreHot);

    // 팔 색 변조 (미세하게)
    float hueShift = sin(spiral * 0.5) * 0.05;
    col += vec3(hueShift, -hueShift * 0.3, hueShift * 0.2);

    // 별 반짝임
    float sparkle = fract(sin(dot(uv * 200.0, vec2(12.9898, 78.233))) * 43758.5453);
    sparkle = smoothstep(0.97, 1.0, sparkle) * falloff * 0.2;
    density += sparkle;

    // 원형 마스크
    float edgeMask = 1.0 - smoothstep(0.8, 1.0, r * max(a_ellipticity, 0.3));
    density *= edgeMask;

    gl_FragColor = vec4(col * density, density) * v_color_mix;
}
