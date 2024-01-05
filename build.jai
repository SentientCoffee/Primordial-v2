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
ASSET_DIR     :: "assets";

MODULE_IMPORT_PATHS :: string.["modules"];

SHADER_CACHE_DIR :: #run tprint("%/%", ASSET_DIR, "_shader_cache");

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

    if shader_compile && file_exists(SHADER_CACHE_DIR) then delete_directory(SHADER_CACHE_DIR);
    make_directory_if_it_does_not_exist(SHADER_CACHE_DIR, recursive = true);

    w_debug := compiler_create_workspace("Primordial debug");
    options := get_build_options(w_debug);

    options.import_path                         = aggregate_import_paths(MODULE_IMPORT_PATHS, options.import_path);
    options.output_path                         = exe_path;     // :InconsistentDirectoryMaking
    options.intermediate_path                   = tprint("%/_int", BUILD_DIR);
    options.output_executable_name              = tprint("%_d", MAIN_EXE_NAME);
    options.backend                             = .LLVM;        // There's a bug with with isa types in the x64 backend, switch back when fixed
    options.use_natvis_compatible_types         = false;
    options.shorten_filenames_in_error_messages = true;
    options.text_output_flags                  &= ~.OUTPUT_LINK_LINE;

    set_optimization(*options, .DEBUG);
    set_build_options(options, w_debug);

    // import_paths_to_check : [..]string;
    compiler_begin_intercept(w_debug);
    {
        // cached_build_string_path := tprint("%/_genereated_asset_table.jai", SHADER_CACHE_DIR);

        // if shader_compile {
        //     write_strings("----------\n", "Compiling shaders:\n");

        //     shader_build_string=, success := compile_shaders();
        //     if !success {
        //         compiler_set_workspace_status(.FAILED, w_debug);
        //         return;
        //     }

        //     success = write_entire_file(cached_build_string_path, shader_build_string);
        //     if !success {
        //         compiler_report(tprint("Failed to write generated build string to \"%\"", cached_build_string_path), mode = .WARNING);
        //     }
        // }
        // else {
        //     shader_build_string=, success := read_entire_file(cached_build_string_path);
        //     if !success {
        //         compiler_report(tprint("Failed to read cached build string from \"%\"", cached_build_string_path));
        //         return;
        //     }
        // }

        // assert(shader_build_string != "", "Something went wrong and we got an empty shader_table build string.");

        write_strings("----------\n", "Generating asset table:\n");
        asset_table_string, success := generate_asset_table(shader_compile);
        if !success {
            compiler_set_workspace_status(.FAILED, w_debug);
            return;
        }

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

                    add_build_string(asset_table_string, w_debug);
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

    write_strings("----------\n", "Shared libraries copied:\n");
    for MODULE_IMPORT_PATHS {
        dylibs : [..]File_Visit_Info;
        dylibs.allocator = temp;

        #if OS == .WINDOWS {
            visit_files(dir_name = it, recursive = true, user_data = *dylibs, proc = find_dlls);
        }
        else {
            visit_files(dir_name = it, recursive = true, user_data = *dylibs, proc = find_shared_objects);
        }

        for dylib : dylibs {
            print("  %\n", dylib.full_name);
            copy_file(dylib.full_name, tprint("%/%", exe_path, dylib.short_name));
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

generate_asset_table :: (compile_shaders : bool) -> string, bool {
    find_images :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
        if !ends_with(info.short_name, ".png") then return;

        new_info := info;
        basename := get_basename_and_path(info.short_name);
        new_info.full_name  = copy_string(info.full_name);
        new_info.short_name = copy_string(basename);

        array_add(user_data, new_info);
    }

    find_shader_binaries :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
        if !ends_with(info.short_name, ".spv") then return;

        new_info := info;
        basename := get_basename_and_path(info.short_name);
        new_info.full_name  = copy_string(info.full_name);
        new_info.short_name = copy_string(basename);

        array_add(user_data, new_info);
    }

    find_shader_sources :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
        if !ends_with(info.short_name, ".glsl") then return;

        new_info := info;
        new_info.full_name  = copy_string(info.full_name);
        new_info.short_name = copy_string(info.short_name);

        array_add(user_data, new_info);
    }

    asset_table_string : String_Builder;
    append(*asset_table_string, "asset_table :: #run -> Hash_Table(string, string) {\n");
    append(*asset_table_string, "    table : Hash_Table(string, string);\n\n");

    found : [..]File_Visit_Info;
    defer array_free(found);
    found.allocator = temp;

    // @Note: Shaders
    append(*asset_table_string, "    // -------------------------------------------------------\n");
    append(*asset_table_string, "    // Shaders\n");
    {
        if compile_shaders {
            visit_files(dir_name = tprint("%/shaders", ASSET_DIR), recursive = true, user_data = *found, proc = find_shader_sources);
            for found {
                outputs, success := compile_shader(it.full_name, SHADER_CACHE_DIR);
                if !success then return "", false;
                for o : outputs {
                    print_to_builder(*asset_table_string, "    table_add(*table, \"%\", \"%\");\n", o.name, o.path);
                }
            }
        }
        else {
            visit_files(dir_name = SHADER_CACHE_DIR, recursive = true, user_data = *found, proc = find_shader_binaries);
            for found {
                print_to_builder(*asset_table_string, "    table_add(*table, \"%\", \"%\");\n", it.short_name, it.full_name);
            }
        }
    }
    append(*asset_table_string, "\n");

    array_reset_keeping_memory(*found);

    // @Note: Textures
    append(*asset_table_string, "    // -------------------------------------------------------\n");
    append(*asset_table_string, "    // Textures\n");
    {
        visit_files(dir_name = tprint("%/textures", ASSET_DIR), recursive = true, user_data = *found, proc = find_images);
        for found {
            print_to_builder(*asset_table_string, "    table_add(*table, \"%\", \"%\");\n", it.short_name, it.full_name);
        }
    }
    append(*asset_table_string, "\n");

    append(*asset_table_string, "    return table;\n}\n");
    return builder_to_string(*asset_table_string), true;
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
    if !ends_with(info.short_name, ".dll") then return;

    new_info := info;
    new_info.full_name  = copy_string(info.full_name);
    new_info.short_name = copy_string(info.short_name);
    array_add(user_data, new_info);
}

find_shared_objects :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
    if !ends_with(info.short_name, ".so") then return;

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
#import "System";
