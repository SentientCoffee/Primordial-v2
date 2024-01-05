Shader_Type :: enum {
    Vertex;
    Fragment;
}

Shader_Output :: struct {
    name : string;
    path : string;
}

// -------------------------------------------------------

advance_string :: (s : *string, count : s64) #expand {
    s.data  += count;
    s.count -= count;
}

// -------------------------------------------------------

compile_shader :: (path : string, output_dir : string) -> outputs : []Shader_Output, compiled : bool {
    shader_name := get_basename_and_path(path);

    shader_buf, ok := read_entire_file(path);
    if !ok {
        print("Failed to read file \"%\"!\n", path);
        return .[], false;
    }

    all_shader_sources := get_shader_sources(shader_buf);

    err := make_directory_if_it_does_not_exist(output_dir); if !err {
        print("Failed to make shader cache directory at \"%\"!\n", output_dir);
        return .[], false;
    }

    shader_dir := tprint("%/%", output_dir, shader_name);
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
        output_path     := tprint("%/%", shader_dir, shader_filename);
        spv_path        := tprint("%.spv", output_path);

        #if DEBUG_SHADERCOMP_OUTPUT then print("Dumping % shader to \"%\"...\n", type, output_path);
        file, ok := file_open(output_path, for_writing = true);
        if !ok {
            print("Failed to open file \"%\" for writing!\n", output_path);
            return .[], false;
        }

        ok_1 := file_write(*file, "#version 450\n");
        ok_2 := file_write(*file, src);

        file_close(*file);

        if !ok_1 || !ok_2 {
            print("Failed to write file \"%\"!\n", output_path);
            return .[], false;
        }

        type_str := tprint("%", type);
        to_lower_in_place(type_str);

        print("Compiling % shader \"%\"...\n", type_str, shader_filename);
        glslc_args := string.[ "glslc", output_path, "-o", spv_path ];
        result, output, error := run_command(..glslc_args, capture_and_return_output = true, arg_quoting = .NEVER_QUOTE);
        if result.type == .FAILED_TO_LAUNCH {
            print("Failed to run command \"%\"!\n", join(..glslc_args, separator = " "));
            return .[], false;
        }

        if output then write_strings("\n", output, "\n");
        if error  then write_strings("\n", error, "\n");

        if result.type == .EXITED && result.exit_code != 0 {
            print("'%' returned with exit code %.\n", join(..glslc_args, separator = " "), result.exit_code);
            return .[], false;
        }

        array_add(*outputs, .{shader_filename, spv_path});

        #if DEBUG_SHADERCOMP_OUTPUT then print("Deleting % shader at \"%\"...\n", type_str, output_path);
        if !file_delete(output_path) {
            error, desc := get_error_value_and_string();
            print("Could not delete file at \"%\": % (Error code: %)\n", output_path, desc, error);
        }
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
                en := to_upper_copy_new(enum_name,, temp);
                if type_token != en then continue;

                shader_type = cast(Shader_Type) shader_ti.values[index];
                break;
            }
        }
    }

    return sources;
}
