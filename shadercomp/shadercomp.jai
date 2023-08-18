Shader_Type :: enum {
    Vertex;
    Fragment;
}

Shader_Output :: struct {
    name : string;
    path : string;
}


advance_string :: (s : *string, count : s64) #expand {
    s.data  += count;
    s.count -= count;
}

// -------------------------------------------------------

compile_shader :: (shader_name : string, path := "assets/shaders", output_shader_dir := "build/shader_cache") -> outputs : []Shader_Output, compiled : bool {
    shader_path := tprint("%/%", path, shader_name);
    shader_buf, ok := read_entire_file(shader_path);
    if !ok {
        print("Failed to read file \"%\"!\n", shader_path);
        return .[], false;
    }

    all_shader_sources := get_shader_sources(shader_buf);

    err := make_directory_if_it_does_not_exist(output_shader_dir); if !err {
        print("Failed to make shader cache directory at \"%\"!\n", output_shader_dir);
        return .[], false;
    }

    shader_dir := tprint("%/%", output_shader_dir, shader_name);
    err = make_directory_if_it_does_not_exist(shader_dir); if !err {
        print("Failed to make directory \"%\"!\n", shader_dir);
        return .[], false;
    }

    outputs : [..]Shader_Output;
    outputs.allocator = temp;
    array_reserve(*outputs, all_shader_sources.count);

    for src, type : all_shader_sources {
        if !src then continue;
        #if DEBUG_SHADERCOMP_OUTPUT then print("----------\n% shader:\n%----------\n", type, src);

        ext : string;
        if type == {
            case .Vertex;   ext = "vert";
            case .Fragment; ext = "frag";
        }
        assert(ext != "");

        shader_filename := tprint("%.%", shader_name, ext);
        shader_path     := tprint("%/%", shader_dir, shader_filename);
        spv_path        := tprint("%.spv", shader_path);

        #if DEBUG_SHADERCOMP_OUTPUT then print("Dumping % shader to \"%\"...\n", type, shader_path);
        file, ok := file_open(shader_path, for_writing = true);
        defer file_close(*file);
        if !ok {
            print("Failed to open file \"%\" for writing!\n", shader_path);
            return .[], false;
        }

        ok_1 := file_write(*file, "#version 450\n");
        ok_2 := file_write(*file, src);

        if !ok_1 || !ok_2 {
            print("Failed to write file \"%\"!\n", shader_path);
            return .[], false;
        }

        print("Compiling % shader \"%\"...\n", type, shader_filename);
        glslc_cmd := tprint("glslc % -o %", shader_path, spv_path);
        result := run_command(glslc_cmd, arg_quoting = .NEVER_QUOTE);
        if result.type == .FAILED_TO_LAUNCH {
            print("Failed to run command \"%\"!\n", glslc_cmd);
            return .[], false;
        }

        // @Todo: Handle compilation errors

        array_add(*outputs, .{shader_filename, spv_path});
    }

    // @Todo: copy shaders to output path

    return outputs, true;
}

get_shader_sources :: (file_data : string) -> Enum_Array(Shader_Type, string) {
    sources : Enum_Array(Shader_Type, string);

    data        := file_data;
    shader_type := Shader_Type.Vertex;
    shader_src  : String_Builder;

    while true {
        newline_idx := find_index_from_left(data, #char "\n");
        defer {
            if newline_idx == -1 {
                sources[shader_type] = builder_to_string(*shader_src);
                break;
            }

            advance_string(*data, newline_idx + 1);
        }

        line := data;
        line.count = newline_idx;

        type_keyword_idx := find_index_from_left(line, "#type ");
        if type_keyword_idx == -1 {
            append(*shader_src, line);
            append(*shader_src, #char "\n");
        }
        else {
            // @Note: If shader_src doesn't have anything don't bother adding it to the array
            shader_string := builder_to_string(*shader_src);
            if shader_string then sources[shader_type] = shader_string;

            type_token := line;
            advance_string(*type_token, "#type ".count);
            to_upper_in_place(type_token);

            shader_ti := type_info(Shader_Type);
            for enum_name, index : shader_ti.names {
                en := to_upper_copy(enum_name);
                if type_token != en then continue;

                shader_type = cast(Shader_Type) shader_ti.values[index];
                break;
            }
        }
    }

    return sources;
}
