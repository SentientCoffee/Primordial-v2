package primordial

import "core:fmt"
import "core:os"
import "core:runtime"
import "core:strings"

import "vendor:glfw"
import vk "vendor:vulkan"

WIDTH  :: 800
HEIGHT :: 600

when ODIN_DEBUG { ENABLE_VALIDATION :: true  }
else            { ENABLE_VALIDATION :: false }

g_validation_layers := [?]cstring {
    "VK_LAYER_KHRONOS_validation",
}

g_context : runtime.Context

main :: proc() {
    // @Note(Daniel):  Init window
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, 0)

    window := glfw.CreateWindow(WIDTH, HEIGHT, "Vulkan", nil, nil)
    defer glfw.DestroyWindow(window);

    // @Note(Daniel):  Load Vulkan global procs
    // @Reference: https://gist.github.com/terickson001/bdaa52ce621a6c7f4120abba8959ffe6#file-main-odin-L216
    vk.load_proc_addresses_global(cast(rawptr) glfw.GetInstanceProcAddress);

    // @Note(Daniel):  Query available extensions
    available_extension_count : u32
    vk.EnumerateInstanceExtensionProperties(nil, &available_extension_count, nil)
    available_extensions := make([]vk.ExtensionProperties, available_extension_count)
    vk.EnumerateInstanceExtensionProperties(nil, &available_extension_count, raw_data(available_extensions))

    glfw_required_extensions := glfw.GetRequiredInstanceExtensions()
    fmt.printf("Available extensions:\n")
    glfw_available_extension_count := 0
    for ext in &available_extensions {
        ext_name := strings.trim_null(string(ext.extensionName[:]))
        fmt.printf("    {}", ext_name)
        for glfw_ext in glfw_required_extensions {
            if string(glfw_ext) != ext_name { continue }
            glfw_available_extension_count += 1
            fmt.printf(" -- Required by GLFW")
            break
        }
        fmt.println()
    }

    if glfw_available_extension_count != len(glfw_required_extensions) {
        fmt.println("Not all required GLFW extensions are available!")
        os.exit(1)
    }
    else {
        fmt.println("All required GLFW extensions available.")
    }

    required_extensions : [dynamic]cstring
    append(&required_extensions, ..glfw_required_extensions)
    when ENABLE_VALIDATION {
        append(&required_extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
    }

    // @Note(Daniel):  Query available validation layers
    when ENABLE_VALIDATION {
        available_layer_count : u32
        vk.EnumerateInstanceLayerProperties(&available_layer_count, nil)
        available_layers := make([]vk.LayerProperties, available_layer_count)
        vk.EnumerateInstanceLayerProperties(&available_layer_count, raw_data(available_layers))

        for needed_layer in g_validation_layers {
            layer_found := false
            for layer_props in &available_layers {
                layer_name := strings.trim_null(string(layer_props.layerName[:]))
                if string(needed_layer) == layer_name {
                    layer_found = true
                    break
                }
            }

            if !layer_found {
                fmt.printf("Requested validation layer \"{}\" not in available layers!")
                os.exit(1)
            }
        }
    }

    // @Note(Daniel):  Create Vulkan instance
    when ENABLE_VALIDATION {
        instance_debug_messenger_create_info := create_debug_messenger_create_info()
    }

    app_info := vk.ApplicationInfo {
        sType              = .APPLICATION_INFO,
        pApplicationName   = "Hello triangle",
        applicationVersion = vk.MAKE_VERSION(0, 0, 1),
        pEngineName        = "No engine",
        engineVersion      = vk.MAKE_VERSION(0, 0, 1),
        apiVersion         = vk.API_VERSION_1_0,
    }

    instance_create_info := vk.InstanceCreateInfo {
        sType                   = .INSTANCE_CREATE_INFO,
        pApplicationInfo        = &app_info,
        enabledExtensionCount   = cast(u32) len(required_extensions),
        ppEnabledExtensionNames = raw_data(required_extensions),
        enabledLayerCount       = cast(u32) len(g_validation_layers)    when ENABLE_VALIDATION else 0,
        ppEnabledLayerNames     = raw_data(g_validation_layers[:])      when ENABLE_VALIDATION else nil,
        pNext                   = &instance_debug_messenger_create_info when ENABLE_VALIDATION else nil,
    }

    instance : vk.Instance
    if res := vk.CreateInstance(&instance_create_info, nil, &instance); res != .SUCCESS {
        fmt.printf("Failed to create Vulkan instance! Error: {}\n", res)
        os.exit(1)
    }
    defer vk.DestroyInstance(instance, nil)
    vk.load_proc_addresses_instance(instance)

    context.user_ptr = &instance
    g_context = context

    // @Note(Daniel):  Create debug messenger
    when ENABLE_VALIDATION {
        debug_messenger : vk.DebugUtilsMessengerEXT
        debug_messenger_create_info := create_debug_messenger_create_info()
        vk.CreateDebugUtilsMessengerEXT(instance, &debug_messenger_create_info, nil, &debug_messenger)
    }
    defer when ENABLE_VALIDATION {
        vk.DestroyDebugUtilsMessengerEXT(instance, debug_messenger, nil)
    }

    // @Note(Daniel):  Main loop
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents();
    }
}

create_debug_messenger_create_info :: proc() -> vk.DebugUtilsMessengerCreateInfoEXT {
    return {
        sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        messageSeverity = { .VERBOSE, .WARNING, .ERROR },
        messageType     = { .GENERAL, .VALIDATION, .PERFORMANCE },
        pfnUserCallback = debug_callback,
        pUserData       = &g_context,
    }
}

debug_callback :: proc "system" (
    message_severity   : vk.DebugUtilsMessageSeverityFlagsEXT,
    message_type_flags : vk.DebugUtilsMessageTypeFlagsEXT,
    callback_data      : ^vk.DebugUtilsMessengerCallbackDataEXT,
    user_data          : rawptr,
) -> b32 {
    context = (cast(^runtime.Context) user_data)^
    fmt.printf(
        "Validation layer{1}: {0}\n",
        callback_data.pMessage,
        " warning" if message_severity >= { .WARNING } else
        " error"   if message_severity >= { .ERROR   } else "",
    )
    return false
}
