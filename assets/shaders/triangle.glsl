#type VERTEX

layout(binding = 0) uniform Matrices {
    mat4 model;
    mat4 view;
    mat4 proj;
} u_mtx;

layout(location = 0) in vec3 i_position;
layout(location = 1) in vec3 i_color;
layout(location = 2) in vec2 i_uv;

layout(location = 0) out vec3 o_color;
layout(location = 1) out vec2 o_uv;

void main() {
    int row = gl_InstanceIndex / 5;
    int col = gl_InstanceIndex % 5;

    float x = i_position.x + (row - 2) * 1.5;
    float y = i_position.y + (col - 2) * 1.5;

    gl_Position = u_mtx.proj * u_mtx.view * u_mtx.model * vec4(x, y, i_position.z, 1.0);
    o_color = i_color;
    o_uv = i_uv;
}

#type FRAGMENT

layout(binding = 1) uniform sampler2D u_sampler;

layout(location = 0) in vec3 i_color;
layout(location = 1) in vec2 i_uv;

layout(location = 0) out vec4 o_color;

void main() {
    vec4 color = texture(u_sampler, i_uv);
    color *= vec4(i_color, 1.0);
    // vec4 color = vec4(i_color, 1.0);
    o_color = color;
}
