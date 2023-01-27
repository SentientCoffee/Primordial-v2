package shadercomp

import "core:path/filepath"
import "core:fmt"
import "core:c/libc"
import "core:mem"
import "core:os"
import "core:strings"

Shader_Type :: enum {
    None,
    Vertex,
    Fragment,
}

main :: proc() {
    FILENAME :: "triangle.glsl"

    fmt.printf("\nHellope from shadercomp in \x1b[1m{}\x1b[0m\n", os.get_current_directory())
    buf : []byte
    {
        ok : bool
        if buf, ok = os.read_entire_file("assets/shaders/" + FILENAME); !ok {
            fmt.printf("Failed to read file \"{}\"!\n", FILENAME)
            os.exit(1)
        }
    }

    sr : strings.Reader
    strings.reader_init(&sr, string(buf))

    all_shader_sources : [Shader_Type]string
    shader_type := Shader_Type.None
    shader_src : [dynamic]byte

    for {
        idx := strings.index(string(buf), "\n")
        if idx == -1 {
            // @Note(Daniel): Stomp the last newline
            all_shader_sources[shader_type] = string(shader_src[:len(shader_src) - 1])
            break
        }
        line := buf[:idx]

        TYPE_KEYWORD :: "#type "
        if type_keyword_idx := strings.index(string(line), TYPE_KEYWORD); type_keyword_idx != -1 {
            if len(shader_src) > 0 {
                // @Note(Daniel): Stomp the last newline
                all_shader_sources[shader_type] = strings.clone_from_bytes(shader_src[:len(shader_src) - 1])
                clear(&shader_src)
            }

            type_token_idx := type_keyword_idx + len(TYPE_KEYWORD)
            end_idx        := len(line)
            type_token_buf := line[type_token_idx:end_idx]
            if type_token_buf[len(type_token_buf) - 1] == '\r' {
                type_token_buf = type_token_buf[:len(type_token_buf) - 1]
            }

            type_token := strings.to_upper(string(type_token_buf))
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

    top_shader_dir := filepath.join({ os.get_current_directory(), "build", "shader_cache" })
    if err := os.make_directory(top_shader_dir); err != 0 {
        fmt.printf("Failed to make shader cache directory at \"{}\"!\nError:{}\n", top_shader_dir, err)
        os.exit(1)
    }

    shader_dir := filepath.join({ top_shader_dir, FILENAME })
    if err := os.make_directory(shader_dir); err != 0 {
        fmt.printf("Failed to make directory \"{}\"!\nError: {}\n", shader_dir, err)
        os.exit(1)
    }

    for src, type in all_shader_sources {
        if len(src) <= 0 { continue }

        ext : cstring
        #partial switch type {
            case .Vertex:   ext = "vert"
            case .Fragment: ext = "frag"
        }

        shader_filename := fmt.tprintf("{}.{}", FILENAME, ext)
        shader_path := filepath.join({ shader_dir, shader_filename })

        fmt.printf("Dumping {} shader to \"{}\"...\n", type, shader_path)
        if ok := os.write_entire_file(shader_path, mem.ptr_to_bytes(raw_data(src), len(src))); !ok {
            fmt.printf("Failed to write file \"{}\"!\n", shader_path)
            os.exit(1)
        }

        fmt.printf("Compiling {} shader \"{}\"...\n", type, shader_filename)
        glslc_cmd := strings.unsafe_string_to_cstring(fmt.tprintf("glslc {0} -o {0}.spv\x00", shader_path))
        libc.system(glslc_cmd)
    }

}
