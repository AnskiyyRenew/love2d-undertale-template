// FourPoint.glsl
// Perspective-correct four-point texture deformation shader.
// Takes 4 corner coordinates and maps the texture to fill the quadrilateral.
// p1 = top-left, p2 = top-right, p3 = bottom-left, p4 = bottom-right

extern vec2 p1;
extern vec2 p2;
extern vec2 p3;
extern vec2 p4;

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) {
    // Solve for UV coordinates given screen position using inverse bilinear interpolation
    // Forward mapping: P = (1-u)(1-v)*p1 + u(1-v)*p2 + (1-u)v*p3 + uv*p4
    // Rearranged:     P = p1 + u*(p2-p1) + v*(p3-p1) + u*v*(p4-p3-p2+p1)
    // Let A=p2-p1, B=p3-p1, C=p4-p3-p2+p1, D=P-p1
    // Then: D = u*A + v*B + u*v*C
    //
    // Solve quadratic a*v² + b*v + c = 0 where:
    //   a = By*Cx - Cy*Bx
    //   b = By*Ax - Ay*Bx + Cy*Dx - Dy*Cx
    //   c = Ay*Dx - Dy*Ax

    vec2 A = p2 - p1;
    vec2 B = p3 - p1;
    vec2 C = p4 - p3 - p2 + p1;
    vec2 D = screen_coords - p1;

    float a = B.y * C.x - C.y * B.x;
    float b = B.y * A.x - A.y * B.x + C.y * D.x - D.y * C.x;
    float c = A.y * D.x - D.y * A.x;

    float v;
    if (abs(a) < 0.00001) {
        // Linear case (parallelogram or near-parallelogram)
        if (abs(b) < 0.00001) {
            v = 0.0;
        } else {
            v = -c / b;
        }
    } else {
        float disc = b * b - 4.0 * a * c;
        if (disc < 0.0) disc = 0.0;
        v = (-b + sqrt(disc)) / (2.0 * a);
    }

    // Solve for u
    float denom = A.y + v * C.y;
    float u;
    if (abs(denom) < 0.00001) {
        u = (D.x - v * B.x) / (A.x + v * C.x + 0.00001);
    } else {
        u = (D.y - v * B.y) / denom;
    }

    // Discard pixels outside the quadrilateral (UV outside [0,1])
    if (u < -0.001 || u > 1.001 || v < -0.001 || v > 1.001) {
        discard;
    }

    // Sample the texture at the computed UV coordinates
    vec4 pixel = Texel(tex, vec2(clamp(u, 0.0, 1.0), clamp(v, 0.0, 1.0)));
    return pixel * color;
}
