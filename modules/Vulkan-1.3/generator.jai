// MIT License - Copyright (c) 2022-2023 Hamad Almamari
// You can use this file to generate any version of vulkan bindings.
// You only need to set the vulkan.h and vulkan lib paths.
// Modified by Ryan Capote and Daniel Presas for Vulkan 1.3.250

// config
AT_COMPILE_TIME   :: true;
vulkan_h_location :: "src/vulkan.h";

#if OS == .WINDOWS {
    extra_source_files :: string.["src/vulkan_win32.h"];
} else #if OS == .LINUX {
    extra_source_files :: string.[];
}

#if AT_COMPILE_TIME then #run {
    set_build_options_dc(.{do_output=false});
    if !generate_bindings() {
        compiler_set_workspace_status(.FAILED);
    }
    if !generate_loader() {
        compiler_set_workspace_status(.FAILED);
    }
}
else {
    #import "System";

    #run {
        make_directory_if_it_does_not_exist("build");
        set_build_options_dc(.{output_executable_name = "vulkan_bindings_gen", output_path = "build"});

        libclang_path := "build/libclang.dll";
        if !file_exists(libclang_path) {
            log_error("We need libclang.dll to be able to generate bindings...Exiting.");
            compiler_set_workspace_status(.FAILED);
        }
    }

    main :: () {
        if !generate_bindings() {
            exit(1);
        }
        if !generate_loader() {
            exit(1);
        }
    }

}

//--------------------

OMIT_LIST :: string.[
    // These are defined manually:
    "VK_NULL_HANDLE",
    "VK_TRUE",
    "VK_FALSE",
    "VK_WHOLE_SIZE",
    "VK_UUID_SIZE",
    "VK_LUID_SIZE",

    "VK_LOD_CLAMP_NONE",
    "VK_SUBPASS_EXTERNAL",
    "VK_QUEUE_FAMILY_EXTERNAL",

    "VK_ATTACHMENT_UNUSED",
    "VK_QUEUE_FAMILY_IGNORED",
    "VK_SHADER_UNUSED_KHR",

    "VK_REMAINING_ARRAY_LAYERS",
    "VK_REMAINING_MIP_LEVELS",
    "VK_REMAINING_3D_SLICES_EXT",

    "VK_MAX_DESCRIPTION_SIZE",
    "VK_MAX_DEVICE_GROUP_SIZE",
    "VK_MAX_DRIVER_NAME_SIZE",
    "VK_MAX_DRIVER_INFO_SIZE",
    "VK_MAX_EXTENSION_NAME_SIZE",
    "VK_MAX_MEMORY_TYPES",
    "VK_MAX_MEMORY_HEAPS",
    "VK_MAX_PHYSICAL_DEVICE_NAME_SIZE",

    "VkBool32",
];

ProcName :: struct {
    name        : string;
    output_name : string;
}

global_procs   : [..]ProcName;
instance_procs : [..]ProcName;
device_procs   : [..]ProcName;

generate_bindings :: () -> bool {
    #if OS != .WINDOWS && OS != .LINUX {
        #if OS == .MACOS {
            log_error("TODO: make bindings for MacOS");
            return false;
        }
        else {
            log_error("Unsupported OS: %", OS);
            return false;
        }
    }

    #if OS == .WINDOWS {
        output_filename := "generated_windows.jai";
    }
    else #if OS == .LINUX {
        output_filename := "generated_linux.jai";
    }

    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {
            array_add(*extra_clang_arguments, "-x", "c", "-DWIN32_LEAN_AND_MEAN", "-DVK_USE_PLATFORM_WIN32_KHR");
        }

        array_add(*source_files, vulkan_h_location);
        array_add(*system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);

        generate_library_declarations = false;

        array_add(*strip_prefixes, "vk", "Vk", "VK_", "vulkan");
        strip_flags &= ~.SYMBOLS_WITH_UNKNOWN_FOREIGN_LIBS;   // We convert all function calls into declarations so we don't need to strip these

        omit_global_declarations = false;
        footer = VULKAN_FOOTER;

        visitor = vulkan_visitor;
        generate_compile_time_struct_checks = false;
    }

    array_reserve(*global_procs,     5);
    array_reserve(*instance_procs, 128);  // @Todo: Should we do this at all? Or is remember_allocators enough?
    array_reserve(*device_procs,   128);  // @Todo: Should we do this at all? Or is remember_allocators enough?

    success := generate_bindings(opts, output_filename);
    return success;
}

generate_loader :: () -> bool {
    loader_filename := "loader.jai";
    log("Generating \"%\"...\n", loader_filename);

    loader_builder : String_Builder;
    init_string_builder(*loader_builder);

    append(*loader_builder, "//\n// Generated loader file. Do not modify.\n//\n\n");

    //
    // Global procs
    //
    max_proc_name_size := min_of_type(s64);
    append(*loader_builder, "load_global_proc_addresses :: (loader_proc: (proc_name: *u8, user_data: *void) -> PFN_vkVoidFunction, user_data: *void = null) {\n");

    for global_procs {
        if it.output_name.count > max_proc_name_size then max_proc_name_size = it.output_name.count;
    }
    for global_procs {
        print_to_builder(*loader_builder, "    %", it.output_name);
        spaces_to_append := max_proc_name_size - it.output_name.count;
        for 1..spaces_to_append   append(*loader_builder, " ");
        print_to_builder(*loader_builder, " = xx loader_proc(\"%\", user_data);\n", it.name);
    }

    append(*loader_builder, "}\n\n");

    //
    // Instance procs
    //
    max_proc_name_size = min_of_type(s64);
    append(*loader_builder, "load_instance_proc_addresses :: (instance: Instance) {\n");

    for instance_procs {
        if it.output_name.count > max_proc_name_size then max_proc_name_size = it.output_name.count;
    }
    for instance_procs {
        print_to_builder(*loader_builder, "    %", it.output_name);
        spaces_to_append := max_proc_name_size - it.output_name.count;
        for 1..spaces_to_append   append(*loader_builder, " ");
        print_to_builder(*loader_builder, " = xx GetInstanceProcAddr(instance, \"%\");\n", it.name);
    }

    append(*loader_builder, "}\n\n");

    //
    // Device procs
    //
    max_proc_name_size = min_of_type(s64);
    append(*loader_builder, "load_device_proc_addresses :: (device: Device) {\n");

    for device_procs {
        if it.output_name.count > max_proc_name_size then max_proc_name_size = it.output_name.count;
    }
    for device_procs {
        print_to_builder(*loader_builder, "    %", it.output_name);
        spaces_to_append := max_proc_name_size - it.output_name.count;
        for 1..spaces_to_append   append(*loader_builder, " ");
        print_to_builder(*loader_builder, " = xx GetDeviceProcAddr(device, \"%\");\n", it.name);
    }

    append(*loader_builder, "}\n");

    //
    // Write to file
    //
    if !write_entire_file(loader_filename, *loader_builder) {
        log_error("Could not write generated output to \"%\"\n", loader_filename);
        return false;
    }

    log("OK! generated \"%\"\n", loader_filename);
    return true;
}

available_flag_bits : Hash_Table(string, *Enum);
struct_type_decl    : *Enum;

vulkan_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    decl.output_name = stripped_name(decl.output_name);

    // Omit header definitions (ex: VULKAN_H_)
    if decl.kind == .MACRO_DEFINITION && ends_with(decl.name, "_H_") {
        // print("MACRO_DEFINITION removed: %\n", decl.name);
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    // Omit our OMIT_LIST
    if !parent_decl && array_find(OMIT_LIST, decl.name) {
        //print("OMIT_LIST: %\n", decl.name);
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    if decl.kind == .ENUM {
        en := cast(*Enum)decl;
        if en.name == "VkStructureType" {
            struct_type_decl = en; // Save for later
        }

        // Almost all enums should be unsigned
        if en.type && decl.name != "VkResult" {
            if en.type.size == {
                case 1;
                    en.type = context.generator.type_def_u8;
                case 2;
                    en.type = context.generator.type_def_u16;
                case 4;
                    en.type = context.generator.type_def_u32;
                case 8;
                    en.type = context.generator.type_def_u64;
            }
        }

        // Fix LunarG and Khronos being stupid and inconsistent with their enum names
        if decl.name == "VkColorSpaceKHR" {
            for * en.enumerates {
                if begins_with(it.output_name, "COLORSPACE") {
                    it.output_name = "";
                }
                else if begins_with(it.output_name, "SPACE_") {
                    it.output_name.data  += 6;
                    it.output_name.count -= 6;
                }
            }
        }

        if contains(decl.name, "FlagBits") {
            en.flags |= .IS_ENUM_FLAGS;
            en.flags |= .VALUES_IN_HEX;

            for * en.enumerates {
                if contains(it.output_name, "MAX_ENUM") then continue;

                bit_index := find_index_from_left(it.output_name, "_BIT");
                if bit_index != -1 {
                    out             := it.output_name;
                    enum_value_name := slice(out, 0, bit_index);
                    ext_length      := out.count - (bit_index + 4);
                    enum_value_ext  := slice(out, bit_index + 4, ext_length);
                    new_name        := join(enum_value_name, enum_value_ext);
                    it.output_name   = new_name;
                }


            }

            // Remember this so we can replace the generic VkFlags aliases with the actual enum_flag's type below. :VkFlags
            table_add(*available_flag_bits, decl.name, en);
        }

        existing : [..]string;
        for * en.enumerates {
            added := array_add_if_unique(*existing, it.output_name);
            if !added {
                it.output_name = "";
                continue;
            }
        }
    }

    //
    // Replace typedef which has "VkFlags" as value. :VkFlags
    // VkAccessFlags :: VkFlags   ->   VkAccessFlags :: VkAccessFlagBits;
    // We don't change the name of the FlagBits enum directly because both the ...FlagBits and the ...Flags aliases are used in declarations.
    //
    if decl.kind == .TYPEDEF && decl.type.type_of_typedef &&  decl.type.type_of_typedef.name == "VkFlags" {
        //print("TYPEDEF(VkFlags):%\n", << decl.name);
        flags_name := replace(decl.name, "Flags", "FlagBits");
        enum_decl, found := table_find(*available_flag_bits, flags_name);
        if found {
            type := New(CType);
            type.type_of_enum = enum_decl;
            type.size = enum_decl.type.size;
            decl.type = type;
        }
    }

    // Set the default value for sType.
    if parent_decl && parent_decl.kind == .STRUCT && parent_decl.name != "VkBaseInStructure" && parent_decl.name != "VkBaseOutStructure" &&
            decl.kind == .DECLARATION && decl.name == "sType" {

        enum_value_name := get_sType_default_value_from_struct_name(parent_decl.name);

        //
        // Vulkan has inconsistent naming for things, so the generator can't find these enum values because it splits or doesn't split
        // numbers correctly in newer cases. This manually changes the name of the enum so the generator can find it.
        //
        {
            // PhysicalDeviceFeatures/Properties
            if enum_value_name == "PHYSICAL_DEVICE_VULKAN_11_FEATURES"                      then enum_value_name = "PHYSICAL_DEVICE_VULKAN_1_1_FEATURES";
            if enum_value_name == "PHYSICAL_DEVICE_VULKAN_11_PROPERTIES"                    then enum_value_name = "PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES";
            if enum_value_name == "PHYSICAL_DEVICE_VULKAN_12_FEATURES"                      then enum_value_name = "PHYSICAL_DEVICE_VULKAN_1_2_FEATURES";
            if enum_value_name == "PHYSICAL_DEVICE_VULKAN_12_PROPERTIES"                    then enum_value_name = "PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES";
            if enum_value_name == "PHYSICAL_DEVICE_VULKAN_13_FEATURES"                      then enum_value_name = "PHYSICAL_DEVICE_VULKAN_1_3_FEATURES";
            if enum_value_name == "PHYSICAL_DEVICE_VULKAN_13_PROPERTIES"                    then enum_value_name = "PHYSICAL_DEVICE_VULKAN_1_3_PROPERTIES";
            if enum_value_name == "PHYSICAL_DEVICE_SHADER_ATOMIC_INT_64_FEATURES"           then enum_value_name = "PHYSICAL_DEVICE_SHADER_ATOMIC_INT64_FEATURES";
            if enum_value_name == "PHYSICAL_DEVICE_SHADER_FLOAT_16_INT_8_FEATURES"          then enum_value_name = "PHYSICAL_DEVICE_SHADER_FLOAT16_INT8_FEATURES";
            if enum_value_name == "PHYSICAL_DEVICE_TEXTURE_COMPRESSION_ASTCHDR_FEATURES"    then enum_value_name = "PHYSICAL_DEVICE_TEXTURE_COMPRESSION_ASTC_HDR_FEATURES";
            if enum_value_name == "PHYSICAL_DEVICE_SHADER_IMAGE_ATOMIC_INT_64_FEATURES_EXT" then enum_value_name = "PHYSICAL_DEVICE_SHADER_IMAGE_ATOMIC_INT64_FEATURES_EXT";
            if enum_value_name == "PHYSICAL_DEVICE_INDEX_TYPE_UINT_8_FEATURES_EXT"          then enum_value_name = "PHYSICAL_DEVICE_INDEX_TYPE_UINT8_FEATURES_EXT";
            if enum_value_name == "PHYSICAL_DEVICE_RGB_A_10_X_6_FORMATS_FEATURES_EXT"       then enum_value_name = "PHYSICAL_DEVICE_RGBA10X6_FORMATS_FEATURES_EXT";
            if enum_value_name == "PHYSICAL_DEVICE_IMAGE_2_D_VIEW_OF_3_D_FEATURES_EXT"      then enum_value_name = "PHYSICAL_DEVICE_IMAGE_2D_VIEW_OF_3D_FEATURES_EXT";
            if enum_value_name == "PHYSICAL_DEVICE_IMAGE_SLICED_VIEW_OF_3_D_FEATURES_EXT"   then enum_value_name = "PHYSICAL_DEVICE_IMAGE_SLICED_VIEW_OF_3D_FEATURES_EXT";

            // VideoDecode
            if enum_value_name == "VIDEO_DECODE_H_264_PROFILE_INFO_KHR"                     then enum_value_name = "VIDEO_DECODE_H264_PROFILE_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_264_CAPABILITIES_KHR"                     then enum_value_name = "VIDEO_DECODE_H264_CAPABILITIES_KHR";
            if enum_value_name == "VIDEO_DECODE_H_264_SESSION_PARAMETERS_ADD_INFO_KHR"      then enum_value_name = "VIDEO_DECODE_H264_SESSION_PARAMETERS_ADD_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_264_SESSION_PARAMETERS_CREATE_INFO_KHR"   then enum_value_name = "VIDEO_DECODE_H264_SESSION_PARAMETERS_CREATE_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_264_PICTURE_INFO_KHR"                     then enum_value_name = "VIDEO_DECODE_H264_PICTURE_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_264_DPB_SLOT_INFO_KHR"                    then enum_value_name = "VIDEO_DECODE_H264_DPB_SLOT_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_264_PROFILE_INFO_KHR"                     then enum_value_name = "VIDEO_DECODE_H264_PROFILE_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_265_PROFILE_INFO_KHR"                     then enum_value_name = "VIDEO_DECODE_H265_PROFILE_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_265_CAPABILITIES_KHR"                     then enum_value_name = "VIDEO_DECODE_H265_CAPABILITIES_KHR";
            if enum_value_name == "VIDEO_DECODE_H_265_SESSION_PARAMETERS_ADD_INFO_KHR"      then enum_value_name = "VIDEO_DECODE_H265_SESSION_PARAMETERS_ADD_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_265_SESSION_PARAMETERS_CREATE_INFO_KHR"   then enum_value_name = "VIDEO_DECODE_H265_SESSION_PARAMETERS_CREATE_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_265_PICTURE_INFO_KHR"                     then enum_value_name = "VIDEO_DECODE_H265_PICTURE_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_265_DPB_SLOT_INFO_KHR"                    then enum_value_name = "VIDEO_DECODE_H265_DPB_SLOT_INFO_KHR";
            if enum_value_name == "VIDEO_DECODE_H_265_PROFILE_INFO_KHR"                     then enum_value_name = "VIDEO_DECODE_H265_PROFILE_INFO_KHR";

            // Win32 KHR
            if enum_value_name == "WIN_32_SURFACE_CREATE_INFO_KHR"                          then enum_value_name = "WIN32_SURFACE_CREATE_INFO_KHR";
            if enum_value_name == "IMPORT_MEMORY_WIN_32_HANDLE_INFO_KHR"                    then enum_value_name = "IMPORT_MEMORY_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "EXPORT_MEMORY_WIN_32_HANDLE_INFO_KHR"                    then enum_value_name = "EXPORT_MEMORY_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "MEMORY_WIN_32_HANDLE_PROPERTIES_KHR"                     then enum_value_name = "MEMORY_WIN32_HANDLE_PROPERTIES_KHR";
            if enum_value_name == "MEMORY_GET_WIN_32_HANDLE_INFO_KHR"                       then enum_value_name = "MEMORY_GET_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "WIN_32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_KHR"             then enum_value_name = "WIN32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_KHR";
            if enum_value_name == "IMPORT_SEMAPHORE_WIN_32_HANDLE_INFO_KHR"                 then enum_value_name = "IMPORT_SEMAPHORE_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "EXPORT_SEMAPHORE_WIN_32_HANDLE_INFO_KHR"                 then enum_value_name = "EXPORT_SEMAPHORE_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "D_3_D_12_FENCE_SUBMIT_INFO_KHR"                          then enum_value_name = "D3D12_FENCE_SUBMIT_INFO_KHR";
            if enum_value_name == "SEMAPHORE_GET_WIN_32_HANDLE_INFO_KHR"                    then enum_value_name = "SEMAPHORE_GET_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "IMPORT_FENCE_WIN_32_HANDLE_INFO_KHR"                     then enum_value_name = "IMPORT_FENCE_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "EXPORT_FENCE_WIN_32_HANDLE_INFO_KHR"                     then enum_value_name = "EXPORT_FENCE_WIN32_HANDLE_INFO_KHR";
            if enum_value_name == "FENCE_GET_WIN_32_HANDLE_INFO_KHR"                        then enum_value_name = "FENCE_GET_WIN32_HANDLE_INFO_KHR";

            // Win32 EXT
            if enum_value_name == "SURFACE_FULL_SCREEN_EXCLUSIVE_WIN_32_INFO_EXT"           then enum_value_name = "SURFACE_FULL_SCREEN_EXCLUSIVE_WIN32_INFO_EXT";

            // Win32 NV
            if enum_value_name == "IMPORT_MEMORY_WIN_32_HANDLE_INFO_NV"                     then enum_value_name = "IMPORT_MEMORY_WIN32_HANDLE_INFO_NV";
            if enum_value_name == "EXPORT_MEMORY_WIN_32_HANDLE_INFO_NV"                     then enum_value_name = "EXPORT_MEMORY_WIN32_HANDLE_INFO_NV";
            if enum_value_name == "WIN_32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_NV"              then enum_value_name = "WIN32_KEYED_MUTEX_ACQUIRE_RELEASE_INFO_NV";
        }

        enum_value: *Enum.Enumerate;
        for * struct_type_decl.enumerates {
            if it.output_name == enum_value_name {
                enum_value = it;
                break;
            }
        }
        assert(enum_value != null, "Could not find % enum value for \"%\"", struct_type_decl.name, enum_value_name);

        literal := New(Literal);
        literal.literal_kind = .ENUM;
        literal.enum_type = struct_type_decl;
        literal.enum_value = enum_value;
        decl.expression = literal;
    }

    //
    // Make all function be declarations instead, so they can be loaded during runtime
    // and generate tables for global, instance, and device-level procs that need to be loaded
    // (global procs are always in the .lib/.dll/.so,
    //  instance procs must be loaded via `vkGetInstanceProcAddr`,
    //  and device procs must be loaded via `vkGetDeviceProcAddr`)
    //
    if decl.kind == .FUNCTION {
        fn_type := decl.type.type_of_function;
        assert(fn_type != null, "Declaration with kind .FUNCTION does not have type.type_of_function set????");

        if decl.name == {
            case "vkCreateInstance";                       #through;
            case "vkEnumerateInstanceExtensionProperties"; #through;
            case "vkEnumerateInstanceLayerProperties";     #through;
            case "vkEnumerateInstanceVersion";             #through;
            case "vkGetInstanceProcAddr";
                array_add(*global_procs, .{
                    name        = copy_string(decl.name, allocator = global_procs.allocator),
                    output_name = copy_string(decl.output_name, allocator = global_procs.allocator),
                });
            case "vkGetDeviceProcAddr";
                array_add(*instance_procs, .{
                    name        = copy_string(decl.name, allocator = instance_procs.allocator),
                    output_name = copy_string(decl.output_name, allocator = instance_procs.allocator),
                });
            case;
                if fn_type.arguments[0].type.type_of_typedef {
                    arg_type_name := fn_type.arguments[0].type.type_of_typedef.declaration.name;
                    if arg_type_name == {
                        case "VkInstance";       #through;
                        case "VkPhysicalDevice";
                            array_add(*instance_procs, .{
                                name        = copy_string(decl.name, allocator = instance_procs.allocator),
                                output_name = copy_string(decl.output_name, allocator = instance_procs.allocator),
                            });
                        case "VkDevice";         #through;
                        case "VkQueue";          #through;
                        case "VkCommandBuffer";
                            array_add(*device_procs, .{
                                name        = copy_string(decl.name, allocator = device_procs.allocator),
                                output_name = copy_string(decl.output_name, allocator = device_procs.allocator),
                            });
                    }
                }
        }

        decl.kind = .DECLARATION;
        decl.foreign_name = "";
    }

    return .RECURSE;
}

get_sType_default_value_from_struct_name :: (name: string) -> string {
    assert(name.count >= 3);

    is_upper :: (byte: u8) -> bool {
        if byte >= #char "A" && byte <= #char "Z" return true;
        return false;
    }

    is_num :: (byte: u8) -> bool {
        if byte >= #char "0" && byte <= #char "9" return true;
        return false;
    }

    builder: String_Builder;
    append(*builder, name[2]);
    for i:3..name.count-1 {
        if is_upper(name[i]) {
            is_first_uppercase := !is_upper(name[i-1]);
            is_end_of_uppercase_word := (i != name.count-1 && !is_upper(name[i+1]));
            is_bit_count := is_num(name[i-1]) && slice(name, i, 3) == "Bit";
            if (is_first_uppercase || is_end_of_uppercase_word) && !is_bit_count {
                append(*builder, #char "_");
            } else if (i >= 4 && slice(name, i-4, 4) == "AABB") { // Special case hack for names involing AABB
                append(*builder, #char "_");
            }
            append(*builder, name[i]);
        } else if is_num(name[i]) {
            if !is_num(name[i-1]) {
                append(*builder, #char "_");
            }
            append(*builder, name[i]);
        } else {
            append(*builder, to_upper(name[i]));
        }
    }

    return builder_to_string(*builder);
}

#scope_file

#if OS == .WINDOWS {

VULKAN_FOOTER :: #string __JAI
#scope_file

#import "Windows";
__JAI

}
else {

VULKAN_FOOTER :: "";

}

//--------------------

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "Check";
#import "File";
#import "File_Utilities";
#import "String";

using,only(min_of_type) #import "Sloppy_Math";

using,except(Table) HT :: #import "Hash_Table";
Hash_Table :: HT.Table;
