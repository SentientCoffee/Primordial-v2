// TODO:
// - build.jai
//   - [ ] Copy shader_cache next to exe
//   - [ ] Recurse the assets file tree
//     - [ ] Check modtime/size to only update asset tables when changed
//   - [ ] Release build
//
// - shadercomp.jai
//   - [?] Handle compilation errors
//   - [ ] Make shader_table be a table to spir-v data, rather than output file paths
//   - [ ] Handle more shader types
//   - [ ] Handle not having "#type" markers?
//

MAIN_EXE_NAME :: "primordial";
BUILD_DIR     :: "build";
ASSET_DIR     :: "assets";

MODULE_IMPORT_PATHS :: string.["modules"];  // @Todo: Cleanup

SHADER_CACHE_DIR :: #run tprint("%/%", ASSET_DIR, ".shader_cache");

DEBUG_SHADERCOMP_OUTPUT :: true;

// -------------------------------------------------------

build :: () {
    set_build_options_dc(.{do_output=false});

    jai_version: Version_Info;
    print("Jai version: %\n", compiler_get_version_info(*jai_version));
    if jai_version.major < 0 || jai_version.minor < 1 || jai_version.micro < 81 {
        print("This program requires Jai version 0.1.81 or higher!\n");
        return;
    }

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

    options.import_path                         = aggregate_import_paths(MODULE_IMPORT_PATHS, options.import_path);  // @Todo: Cleanup
    options.output_path                         = exe_path;     // :InconsistentDirectoryMaking
    options.intermediate_path                   = tprint("%/.int", BUILD_DIR);
    options.output_executable_name              = tprint("%_d", MAIN_EXE_NAME);
    options.backend                             = .LLVM;        // There's a bug with with #type,isa types in the x64 backend, switch back when fixed
    options.use_natvis_compatible_types         = false;
    options.shorten_filenames_in_error_messages = true;
    options.text_output_flags                  &= ~.OUTPUT_LINK_LINE;

    set_optimization(*options, .DEBUG);
    set_build_options(options, w_debug);


    print("----------\nGenerating asset table...\n");
    asset_table_string := generate_asset_table();
    print("----------");

    // import_paths_to_check: [..]string;
    shader_attributes: Enum_Array(Shader_Stage, *Type_Info);
    compiler_begin_intercept(w_debug);
    {
        build_strings_inserted := false;
        add_build_file("primordial/main.jai", w_debug);
        while message_loop := true {
            m := compiler_wait_for_message();
            if !m then break message_loop;

            if m.kind == {
                // case .IMPORT;
                //     mi := cast(*Message_Import) m;
                //     if m.module_type != .FILE then continue;

                //     basename, path := get_basename_and_path(mi.fully_pathed_filename);
                //     if basename != "module" then continue;
                //     path.count -= 1;  // @Note: Stomp the last "/" to avoid it being printed
                //     array_add_if_unique(*import_paths_to_check, path);

                case .TYPECHECKED;
                    mt := cast(*Message_Typechecked) m;
                    if error_checking then do_error_checking(null, mt);

                    if shader_compile then for mt.structs {
                        struct_ti := cast(*Type_Info_Struct) it.expression.defined_type;
                        if struct_ti.name == {
                            case "Vertex";      shader_attributes[Shader_Stage.Vertex]   = struct_ti;
                            case "Render_Pass"; shader_attributes[Shader_Stage.Fragment] = struct_ti;
                        }
                    }

                case .PHASE;
                    mp := cast(*Message_Phase) m;
                    if mp.phase != .TYPECHECKED_ALL_WE_CAN then continue;
                    if build_strings_inserted then continue;

                    add_build_string(asset_table_string, w_debug);
                    build_strings_inserted = true;

                case .ERROR;
                    return;

                case .COMPLETE;
                    break message_loop;
            }
        }
    }
    compiler_end_intercept(w_debug);

    print("----------\nShared libraries copied:\n");
    copy_shared_libs_to_output(exe_path);

    if shader_compile {
        print("----------\nCompiling shaders...\n");
        if !compile_shaders(shader_attributes) {
            compiler_set_workspace_status(.FAILED);
            return;
        }
    }

    if run_after_build {
        print("----------\n");
        if !run() {
            compiler_set_workspace_status(.FAILED);
            return;
        }
    }

    print("----------\nDone.\n");
}

#run build();

// -------------------------------------------------------

generate_asset_table :: () -> string {
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

    asset_table_string: String_Builder;
    append(*asset_table_string, "asset_table :: #run -> Hash_Table(string, string) {\n");
    append(*asset_table_string, "    table: Hash_Table(string, string);\n\n");

    found: [..]File_Visit_Info;
    defer array_free(found);
    found.allocator = temp;

    // @Note: Shaders
    append(*asset_table_string, "    // -------------------------------------------------------\n");
    append(*asset_table_string, "    // Shaders\n");
    {
        visit_files(dir_name = SHADER_CACHE_DIR, recursive = true, user_data = *found, proc = find_shader_binaries);
        for found {
            print_to_builder(*asset_table_string, "    table_add(*table, \"%\", \"%\");\n", it.short_name, it.full_name);
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
    return builder_to_string(*asset_table_string);
}

copy_shared_libs_to_output :: (exe_path: string) {
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

    for path : MODULE_IMPORT_PATHS {
        found: [..]File_Visit_Info;
        found.allocator = temp;

        #if OS == .WINDOWS {
            visit_files(dir_name = path, recursive = true, user_data = *found, proc = find_dlls);
        }
        else {
            visit_files(dir_name = path, recursive = true, user_data = *found, proc = find_shared_objects);
        }

        for found {
            print("    %\n", it.full_name);
            copy_file(it.full_name, tprint("%/%", exe_path, it.short_name));
        }
    }
}

compile_shaders :: (shader_attributes: Enum_Array(Shader_Stage, *Type_Info)) -> bool {
    find_shader_sources :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
        if !ends_with(info.short_name, ".glsl") then return;

        new_info := info;
        new_info.full_name  = copy_string(info.full_name);
        new_info.short_name = copy_string(info.short_name);

        array_add(user_data, new_info);
    }

    found: [..]File_Visit_Info;
    visit_files(dir_name = tprint("%/shaders", ASSET_DIR), recursive = true, user_data = *found, proc = find_shader_sources);
    for found {
        success := compile_shader(it.full_name, shader_attributes);
        if !success then return false;
    }

    return true;
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

aggregate_import_paths :: (paths: ..[]string) -> []string {
    total_size := 0;
    for paths {
        total_size += it.count;
    }

    aggregated: [..] string;
    for p : paths {
        for p  array_add_if_unique(*aggregated, it);
    }

    print("Import paths: %\n", aggregated);
    return aggregated;
}

// -------------------------------------------------------

#load "shadercomp/shadercomp.jai";

// -------------------------------------------------------

#import "Enum_Array";

#import "Basic";
#import "Check";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "String";
#import "System";
