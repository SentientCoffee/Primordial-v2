#type VERTEX
#version 450

layout(location = 0) out vec3 o_frag_color;

vec2 positions[3] = vec2[](
    vec2( 0.0, -0.5),
    vec2( 0.5,  0.5),
    vec2(-0.5,  0.5)
);

vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    o_frag_color = colors[gl_VertexIndex];
}

#type FRAGMENT
#version 450

layout(location = 0) in vec3 i_frag_color;

layout(location = 0) out vec4 o_color;

void main() {
    o_color = vec4(i_frag_color, 1.0);
}
