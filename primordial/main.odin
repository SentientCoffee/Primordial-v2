package primordial

import "core:fmt"
import "core:strings"

import "vendor:glfw"
import vk "vendor:vulkan"

WIDTH  :: 800
HEIGHT :: 600

when ODIN_DEBUG {
    ENABLE_VALIDATION :: true
}
else {
    ENABLE_VALIDATION :: false
}

validation_layers := [?]cstring {
    "VK_LAYER_KHRONOS_validation",
}

main :: proc() {
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, 0)

    window := glfw.CreateWindow(WIDTH, HEIGHT, "Vulkan", nil, nil)
    defer glfw.DestroyWindow(window);

    // @Reference: https://gist.github.com/terickson001/bdaa52ce621a6c7f4120abba8959ffe6#file-main-odin-L216
    instance : vk.Instance
    context.user_ptr = &instance
    vk.load_proc_addresses(proc(p: rawptr, name: cstring) {
        (cast(^rawptr) p)^ = glfw.GetInstanceProcAddress((^vk.Instance)(context.user_ptr)^, name)
    });

    app_info := vk.ApplicationInfo {
        sType              = .APPLICATION_INFO,
        pApplicationName   = "Hello triangle",
        applicationVersion = vk.MAKE_VERSION(0, 0, 1),
        pEngineName        = "No engine",
        engineVersion      = vk.MAKE_VERSION(0, 0, 1),
        apiVersion         = vk.API_VERSION_1_0,
    }

    create_info := vk.InstanceCreateInfo {
        sType                   = .INSTANCE_CREATE_INFO,
        pApplicationInfo        = &app_info,
        enabledExtensionCount   = cast(u32) len(glfw_required_extensions),
        ppEnabledExtensionNames = raw_data(glfw_required_extensions),
        enabledLayerCount       = 0,
    }

    if vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS {
        fmt.println("Failed to create Vulkan instance!")
        return
    }
    defer vk.DestroyInstance(instance)

    extension_count : u32
    vk.EnumerateInstanceExtensionProperties(nil, &extension_count, nil)
    extensions := make([]vk.ExtensionProperties, extension_count)
    vk.EnumerateInstanceExtensionProperties(nil, &extension_count, raw_data(extensions))

    glfw_required_extensions := glfw.GetRequiredInstanceExtensions()
    fmt.printf("Available extensions ({} required by GLFW):\n", len(glfw_required_extensions))
    glfw_avail_extension_count := 0
    for ext in &extensions{
        ext_name := strings.trim_null(string(ext.extensionName[:]))
        fmt.printf("    {}", ext_name)
        for glfw_ext in glfw_required_extensions {
            if string(glfw_ext) != ext_name { continue }
            glfw_avail_extension_count += 1
            fmt.printf(" -- Required by GLFW")
            break
        }
        fmt.println()
    }

    if glfw_avail_extension_count != len(glfw_required_extensions) {
        fmt.println("Not all required GLFW extensions are available!")
        return
    }
    else {
        fmt.println("All required GLFW extensions available.")
    }



    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents();
    }
}

