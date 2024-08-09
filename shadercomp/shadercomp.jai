Shader_Stage :: enum {
    Vertex;
    Fragment;
}

// -------------------------------------------------------

advance_string :: (s : *string, count : s64) #expand {
    s.data  += count;
    s.count -= count;
}

// -------------------------------------------------------

compile_shader :: (path : string, shader_attributes : Enum_Array(Shader_Stage, *Type_Info), output_dir := SHADER_CACHE_DIR) -> bool {
    shader_name := get_basename_and_path(path);

    shader_buf, ok := read_entire_file(path);
    if !ok {
        print("Failed to read file \"%\"!\n", path);
        return false;
    }

    all_shader_sources := get_shader_sources(shader_buf);

    err := make_directory_if_it_does_not_exist(output_dir); if !err {
        print("Failed to make shader cache directory at \"%\"!\n", output_dir);
        return false;
    }

    shader_dir := tprint("%/%", output_dir, shader_name);
    err = make_directory_if_it_does_not_exist(shader_dir); if !err {
        print("Failed to make directory \"%\"!\n", shader_dir);
        return false;
    }

    for src, type : all_shader_sources {
        if !src then continue;

        type_str := tprint("%", type);
        to_lower_in_place(type_str);

        ext : string;
        if #complete type == {
            case .Vertex;   ext = "vert";
            case .Fragment; ext = "frag";
        }
        assert(ext != "");

        shader_filename := tprint("%.%", shader_name, ext);
        output_path     := tprint("%/%", shader_dir, shader_filename);
        spv_path        := tprint("%.spv", output_path);

        #if DEBUG_SHADERCOMP_OUTPUT then print("Dumping % shader to \"%\"...\n", type_str, output_path);
        file, ok := file_open(output_path, for_writing = true);
        if !ok {
            print("Failed to open file \"%\" for writing!\n", output_path);
            return false;
        }

        builder : String_Builder;
        print_to_builder(*builder, "//\n// Generated from %:\n//\n", #file);
        append(*builder, "#version 460\n\n");
        if shader_attributes[type] != null {
            if type == .Vertex {
                assert(shader_attributes[type].type == .STRUCT);
                for member : (cast(*Type_Info_Struct) shader_attributes[type]).members {
                    location : string;
                    for note : member.notes {
                        LOCATION :: "Location=";
                        if !starts_with(note, LOCATION) then continue;
                        location = string.{note.count - LOCATION.count, note.data + LOCATION.count};
                        break note;
                    }

                    typename : string;
                    if member.type.type == .STRUCT {
                        member_ti := cast(*Type_Info_Struct) member.type;
                        if member_ti.name == {
                            case "Vector2"; typename = "vec2";
                            case "Vector3"; typename = "vec3";
                        }
                    }

                    print_to_builder(*builder, "layout(location = %) in % i_%;\n", location, typename, member.name);
                }

                // case .Fragment;
                //     assert(shader_attributes[type].type == .STRUCT);
                //     for member : (cast(*Type_Info_Struct) shader_attributes[type]).members {
                //         if member.name != "attachments" then continue;
                //         for note, idx : member.notes {
                //             print_to_builder(*builder, "layout(location = %) out vec4 o_%;\n", idx, to_lower_copy_new(note,, temp));
                //             break note;
                //         }
                //     }
            }

            append(*builder, "//\n// Generated end\n//\n");
        }

        append(*builder, src);
        if !write_entire_file(output_path, builder_to_string(*builder)) {
            print("Failed to write to file \"%\"!\n", output_path);
            return false;
        }

        print("Compiling % shader \"%\"...\n", type_str, shader_filename);
        glslc_args := string.[ "glslc", output_path, "-o", spv_path ];
        result, output, error := run_command(..glslc_args, capture_and_return_output = true);
        if result.type == .FAILED_TO_LAUNCH {
            print("Failed to run command \"%\"!\n", join(..glslc_args, separator = " "));
            return false;
        }

        if output then write_strings("\n", output, "\n");
        if error  then write_strings("\n", error, "\n");

        if result.type == .EXITED && result.exit_code != 0 {
            print("'%' returned with exit code %.\n", join(..glslc_args, separator = " "), result.exit_code);
            return false;
        }

        #if !DEBUG_SHADERCOMP_OUTPUT {
            if !file_delete(output_path) {
                error, desc := get_error_value_and_string();
                print("Could not delete file at \"%\": % (Error code: %)\n", output_path, desc, error);
            }
        }
    }

    // @Todo: copy shaders to output path

    return true;
}

get_shader_sources :: (file_data : string) -> Enum_Array(Shader_Stage, string) {
    sources : Enum_Array(Shader_Stage, string);

    data        := file_data;
    shader_type := Shader_Stage.Vertex;
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

            shader_ti := type_info(Shader_Stage);
            for enum_name, index : shader_ti.names {
                en := to_upper_copy_new(enum_name,, temp);
                if type_token != en then continue;

                shader_type = cast(Shader_Stage) shader_ti.values[index];
                break;
            }
        }
    }

    return sources;
}
