// TODO:
// - build.jai
//   - [ ] Copy shader_cache next to exe
//   - [ ] Recurse the assets file tree
//     - [ ] Check modtime/size to only update asset tables when changed
//   - [ ] Release build
//
// - shadercomp.jai
//   - [ ] Handle compilation errors
//   - [ ] Make shader_table be a table to spir-v data, rather than output file paths
//   - [ ] Handle more shader types
//   - [ ] Handle not having "#type" markers?
//

MAIN_EXE_NAME :: "primordial";
BUILD_DIR     :: "build";

SHADER_CACHE_DIR :: "shader_cache";

MODULE_IMPORT_PATHS :: string.["modules"];

DEBUG_SHADERCOMP_OUTPUT :: false;

// -------------------------------------------------------

build :: () {
    set_build_options_dc(.{do_output=false});

    error_checking  := false;
    release_build   := false;
    run_after_build := false;
    shader_compile  := false;

    for get_build_options().compile_time_command_line {
        if it == {
            case "check";      error_checking  = true;
            case "release";    release_build   = true;
            case "run";        run_after_build = true;
            case "shadercomp"; shader_compile  = true;
            case;
                compiler_report(tprint("Unknown option \"%\".", it), mode = .WARNING);
        }
    }

    // :InconsistentDirectoryMaking
    // Why does this work for `intermediate_path` but not for `output_path`?
    // Is it because the compiler backend/linker does this for us?
    exe_path := tprint("%/debug", BUILD_DIR);
    if file_exists(exe_path) then delete_directory(exe_path);
    make_directory_if_it_does_not_exist(exe_path, recursive = true);

    shader_cache_path := tprint("%/%", BUILD_DIR, SHADER_CACHE_DIR);
    make_directory_if_it_does_not_exist(shader_cache_path, recursive = true);

    w_debug := compiler_create_workspace("Primordial debug");
    options := get_build_options(w_debug);

    options.import_path                         = aggregate_import_paths(MODULE_IMPORT_PATHS, options.import_path);
    options.output_path                         = exe_path;     // :InconsistentDirectoryMaking
    options.intermediate_path                   = tprint("%/_int", BUILD_DIR);
    options.output_executable_name              = tprint("%_d", MAIN_EXE_NAME);
    options.backend                             = .X64;
    options.use_natvis_compatible_types         = false;
    options.shorten_filenames_in_error_messages = true;
    options.text_output_flags                  &= ~.OUTPUT_LINK_LINE;

    set_optimization(*options, .DEBUG);
    set_build_options(options, w_debug);

    // import_paths_to_check : [..]string;
    compiler_begin_intercept(w_debug);
    {
        cached_build_string_path := tprint("%/_genereated_shader_table.jai", shader_cache_path);
        shader_build_string : string;

        if shader_compile {
            write_strings("----------\n", "Compiling shaders:\n");

            shader_build_string=, success := compile_shaders();
            if !success {
                compiler_set_workspace_status(.FAILED, w_debug);
                return;
            }

            success = write_entire_file(cached_build_string_path, shader_build_string);
            if !success {
                compiler_report(tprint("Failed to write generated build string to \"%\"", cached_build_string_path), mode = .WARNING);
            }
        }
        else {
            shader_build_string=, success := read_entire_file(cached_build_string_path);
            if !success {
                compiler_report(tprint("Failed to read cached build string from \"%\"", cached_build_string_path));
                return;
            }
        }

        assert(shader_build_string != "", "Something went wrong and we got an empty shader_table build string.");

        texture_build_string := get_texture_table_string();

        write_string("----------\n");
        add_build_file("primordial/main.jai", w_debug);

        build_strings_inserted := false;
        while message_loop := true {
            message := compiler_wait_for_message();
            if !message then break message_loop;

            if message.kind == {
                // case .IMPORT;
                //     m := cast(*Message_Import) message;
                //     if m.module_type != .FILE then continue;

                //     basename, path := get_basename_and_path(m.fully_pathed_filename);
                //     if basename != "module" then continue;
                //     path.count -= 1;  // @Note: Stomp the last "/" to avoid it being printed
                //     array_add_if_unique(*import_paths_to_check, path);

                case .TYPECHECKED;
                    if error_checking then do_error_checking(null, message);

                case .PHASE;
                    m := cast(*Message_Phase) message;
                    if m.phase != .TYPECHECKED_ALL_WE_CAN then continue;
                    if build_strings_inserted then continue;

                    add_build_string(shader\_build_string, w_debug);
                    add_build_string(texture_build_string, w_debug);
                    build_strings_inserted = true;

                case .COMPLETE;
                    m := cast(*Message_Complete) message;
                    if m.error_code != .NONE {
                        return;
                    }
                    break message_loop;
            }
        }
    }
    compiler_end_intercept(w_debug);

    write_strings("----------\n", "DLLs copied:\n");
    for MODULE_IMPORT_PATHS {
        dlls : [..]File_Visit_Info;
        dlls.allocator = temp;

        visit_files(dir_name = it, recursive = true, user_data = *dlls, proc = find_dlls);

        for dll : dlls {
            print("  %\n", dll.full_name);
            copy_file(dll.full_name, tprint("%/%", exe_path, dll.short_name));
        }
    }
    write_string("\n");

    if run_after_build {
        write_string("----------\n");
        if !run() {
            compiler_set_workspace_status(.FAILED);
            return;
        }
    }

    write_strings("----------\n", "Done.\n");
}

#run build();

// -------------------------------------------------------

get_texture_table_string :: () -> string {
    find_images :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
        if !ends_with(info.short_name, ".png") return;

        new_info := info;
        basename := get_basename_and_path(info.short_name);

        new_info.full_name  = copy_string(info.full_name);
        new_info.short_name = copy_string(basename);
        array_add(user_data, new_info);
    }

    images : [..]File_Visit_Info;
    images.allocator = temp;

    // @Todo: don't hardcode the directory
    visit_files(dir_name = "assets/textures", recursive = true, user_data = *images, proc = find_images);

    texture_table_string : String_Builder;
    append(*texture_table_string, "texture_table :: #run -> Hash_Table(string, string) {\n");
    append(*texture_table_string, "    table : Hash_Table(string, string);\n\n");
    for images {
        print_to_builder(*texture_table_string, "    table_add(*table, \"%\", \"%\");\n", it.short_name, it.full_name);
    }
    append(*texture_table_string, "\n");
    append(*texture_table_string, "    return table;\n}\n");

    return builder_to_string(*texture_table_string);
}

compile_shaders :: () -> string, bool {
    outputs, success := compile_shader("triangle.glsl");      // @Todo: Recurse the assets/shaders file tree
    if !success then return "", false;

    shader_table_string : String_Builder;
    append(*shader_table_string, "shader_table :: #run -> Hash_Table(string, string) {\n");
    append(*shader_table_string, "    table : Hash_Table(string, string);\n\n");
    append(*shader_table_string, "    // -------------------------------------------------------\n");
    append(*shader_table_string, "    // triangle.glsl\n");
    for outputs {
        print_to_builder(*shader_table_string, "    table_add(*table, \"%\", \"%\");\n", it.name, it.path);
    }
    append(*shader_table_string, "\n");
    append(*shader_table_string, "    return table;\n}\n");

    return builder_to_string(*shader_table_string), true;
}

run :: () -> bool {
    exe_path := tprint("%/debug", BUILD_DIR);
    exe_name := tprint("%_d", MAIN_EXE_NAME);

    run_cmd := tprint("%/%", exe_path, exe_name);
    print("Running \"%\"...\n----------\n", run_cmd);

    process_result := run_command(run_cmd);
    if process_result.type == .FAILED_TO_LAUNCH {
        print("Could not launch \"%\"!", run_cmd);
        return false;
    }

    return true;
}

// -------------------------------------------------------

aggregate_import_paths :: (paths : ..[]string) -> []string {
    total_size := 0;
    for paths {
        total_size += it.count;
    }

    aggregated := NewArray(total_size, string);
    a_ptr := aggregated.data;
    for p : paths {
        for p {
            a_ptr.* = it;
            a_ptr += 1;
        }
    }

    print("Import paths: %\n", aggregated);
    return aggregated;
}

find_dlls :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
    if !ends_with(info.short_name, ".dll") return;

    new_info := info;
    new_info.full_name  = copy_string(info.full_name);
    new_info.short_name = copy_string(info.short_name);
    array_add(user_data, new_info);
}

// -------------------------------------------------------

#load "shadercomp/shadercomp.jai";

// -------------------------------------------------------

#import,file "modules/Enum_Array.jai";

#import "Basic";
#import "Check";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "String";
