package shadercomp

import "core:fmt"
import "core:os"
import "core:strings"

Shader_Type :: enum {
    None,
    Vertex,
    Fragment,
}

main :: proc() {
    fmt.printf("\nHellope from shadercomp in \x1b[1m{}\x1b[0m\n", os.get_current_directory())
    buf : []byte
    {
        ok : bool
        if buf, ok = os.read_entire_file("assets/shaders/triangle.glsl"); !ok {
            fmt.printf("Failed to read file \"{}\"!\n", "triangle.glsl")
            os.exit(1)
        }
    }
    // fmt.printf("\n>>>>>\n{}\n<<<<<\n", string(buf))

    sr : strings.Reader
    strings.reader_init(&sr, string(buf))

    all_shader_sources : [Shader_Type]cstring
    shader_type := Shader_Type.None
    shader_src : [dynamic]byte

    for {
        idx := strings.index(string(buf), "\n")
        if idx == -1 {
            shader_src[len(shader_src) - 1] = 0  // @Note(Daniel): Stomp the last newline with a \0
            all_shader_sources[shader_type] = strings.unsafe_string_to_cstring(string(shader_src[:]))
            break
        }
        line := buf[:idx]

        TYPE_KEYWORD :: "#type "
        if type_keyword_idx := strings.index(string(line), TYPE_KEYWORD); type_keyword_idx != -1 {
            if len(shader_src) > 0 {
                shader_src[len(shader_src) - 1] = 0  // @Note(Daniel): Stomp the last newline with a \0
                all_shader_sources[shader_type] = strings.unsafe_string_to_cstring(strings.clone_from_bytes(shader_src[:]))
                clear(&shader_src)
            }

            type_token_idx := type_keyword_idx + len(TYPE_KEYWORD)
            end_idx    := len(line)

            type_token := strings.to_upper(string(line[type_token_idx:end_idx]))
            switch type_token {
                case "VERTEX":            shader_type = .Vertex
                case "FRAGMENT", "PIXEL": shader_type = .Fragment
                case:                     fmt.printf("-- Unknown type token \"{}\"!\n", type_token); os.exit(1)
            }

            fmt.printf("-- Found type token {}\n", shader_type)
        }
        else {
            append(&shader_src, ..line)
            append(&shader_src, '\n')
        }

        buf = buf[idx + 1:]
    }

    for src, type in all_shader_sources {
        if len(src) <= 0 { continue }
        fmt.println(type, "shader:")
        fmt.println(src)
    }

}
