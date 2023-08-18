#type VERTEX

layout(binding = 0) uniform Matrices {
    mat4 model;
    mat4 view;
    mat4 proj;
} mtx;

layout(location = 0) in vec3 i_position;
layout(location = 1) in vec3 i_color;

layout(location = 0) out vec3 o_frag_color;

void main() {
    gl_Position = mtx.proj * mtx.view * mtx.model * vec4(i_position, 1.0);
    o_frag_color = i_color;
}

#type FRAGMENT

layout(location = 0) in vec3 i_frag_color;

layout(location = 0) out vec4 o_color;

void main() {
    o_color = vec4(i_frag_color, 1.0);
}
