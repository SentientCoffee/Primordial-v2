#type VERTEX
#version 450

layout(location = 0) in vec2 i_position;
layout(location = 1) in vec3 i_color;

layout(location = 0) out vec3 o_frag_color;

void main() {
    gl_Position = vec4(i_position, 0.0, 1.0);
    o_frag_color = i_color;
}

#type FRAGMENT
#version 450

layout(location = 0) in vec3 i_frag_color;

layout(location = 0) out vec4 o_color;

void main() {
    o_color = vec4(i_frag_color, 1.0);
}
