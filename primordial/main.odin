package primordial

import "core:intrinsics"
import "core:fmt"
import "core:log"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"

import "vendor:glfw"
import vk "vendor:vulkan"

WIDTH  :: 800
HEIGHT :: 600

when ODIN_DEBUG { ENABLE_VALIDATION :: true  }
else            { ENABLE_VALIDATION :: false }

g_context : runtime.Context

console_logger_proc :: proc(data : rawptr, level : log.Level, text : string, options : log.Options, location := #caller_location) {
    WHITE  :: "\x1b[0m"
    CYAN   :: "\x1b[36m"
    GREEN  :: "\x1b[92m"
    YELLOW :: "\x1b[93m"
    RED    :: "\x1b[91m"

    // @Note(Daniel): Not using data parameter

    col := WHITE
    if .Level in options {
        if .Terminal_Color in options {
            switch level {
                case .Debug:   col = CYAN
                case .Info:    col = GREEN
                case .Warning: col = YELLOW
                case .Error:   fallthrough
                case .Fatal:   col = RED
            }
        }
    }

    format_str := fmt.tprintf("{}[{: 7s}] {{}} {}{}", col, level, text, WHITE)
    if level == .Fatal {
        loc_str := fmt.tprintf("[{}:{}:{}]", location.file_path, location.line, location.column)
        fmt.printf(format_str, loc_str)
        when ODIN_DEBUG { intrinsics.debug_trap() }
        else { os.exit(1) }
    }
    else {
        loc_str := fmt.tprintf("[{: 15s}:{}:{}]", location.procedure, location.line, location.column)
        fmt.printf(format_str, loc_str)
    }
}

when ODIN_DEBUG {
    import "core:mem"

    main :: proc() {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        _main()

        for _, leak in track.allocation_map {
            fmt.printf("[{}:{}:{}] Leaked {} bytes\n", leak.location.file_path, leak.location.line, leak.location.column, leak.size)
        }
        for bad_free in track.bad_free_array {
            fmt.printf("[{}:{}:{}] Allocation {:p} was freed badly\n", bad_free.location.file_path, bad_free.location.line, bad_free.location.column, bad_free.memory)
        }
    }
}
else {
    main :: proc() { _main() }
}

_main :: proc() {
    // @Note(Daniel): Setup context
    context.logger = log.Logger {
        data         = nil,
        procedure    = console_logger_proc,
        options      = { .Level, .Terminal_Color },
        lowest_level = .Debug when ODIN_DEBUG else .Warning,
    }
    g_context = context

    // @Note(Daniel): Init window
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, 0)

    window := glfw.CreateWindow(WIDTH, HEIGHT, "Vulkan", nil, nil)
    defer glfw.DestroyWindow(window);

    // @Note(Daniel): Load Vulkan global procs
    // @Reference: https://gist.github.com/terickson001/bdaa52ce621a6c7f4120abba8959ffe6#file-main-odin-L216
    vk.load_proc_addresses_global(cast(rawptr) glfw.GetInstanceProcAddress)

    // @Note(Daniel): Get required instance extensions
    available_instance_extension_count : u32
    vk.EnumerateInstanceExtensionProperties(nil, &available_instance_extension_count, nil)
    available_instance_extensions := make([]vk.ExtensionProperties, available_instance_extension_count)
    vk.EnumerateInstanceExtensionProperties(nil, &available_instance_extension_count, raw_data(available_instance_extensions))

    glfw_required_extensions       := glfw.GetRequiredInstanceExtensions()
    available_glfw_extension_count := 0
    for ext in &available_instance_extensions {
        ext_name := strings.trim_null(string(ext.extensionName[:]))
        for glfw_ext in glfw_required_extensions {
            if string(glfw_ext) != ext_name { continue }
            available_glfw_extension_count += 1
            break
        }
    }

    if available_glfw_extension_count != len(glfw_required_extensions) {
        log.panic("Not all required GLFW extensions are available!")
    }

    required_extensions : [dynamic]cstring
    append(&required_extensions, ..glfw_required_extensions)
    when ENABLE_VALIDATION {
        append(&required_extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
    }

    // @Note(Daniel): Get validation layers
    when ENABLE_VALIDATION {
        validation_layers := []cstring {
            "VK_LAYER_KHRONOS_validation",
        }

        available_layer_count : u32
        vk.EnumerateInstanceLayerProperties(&available_layer_count, nil)
        available_layers := make([]vk.LayerProperties, available_layer_count)
        vk.EnumerateInstanceLayerProperties(&available_layer_count, raw_data(available_layers))

        for needed_layer in validation_layers {
            layer_found := false

            for layer_props in &available_layers {
                layer_name := strings.trim_null(string(layer_props.layerName[:]))
                if string(needed_layer) == layer_name {
                    layer_found = true
                    break
                }
            }

            if !layer_found {
                log.panicf("Requested validation layer \"{}\" not in available layers!\n", needed_layer)
            }
        }
    }

    // @Note(Daniel): Create Vulkan instance
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
        enabledExtensionCount   = auto_cast len(required_extensions),
        ppEnabledExtensionNames = raw_data(required_extensions),
        enabledLayerCount       = auto_cast len(validation_layers)      when ENABLE_VALIDATION else 0,
        ppEnabledLayerNames     = raw_data(validation_layers)           when ENABLE_VALIDATION else nil,
        pNext                   = &instance_debug_messenger_create_info when ENABLE_VALIDATION else nil,
    }

    instance : vk.Instance
    if res := vk.CreateInstance(&instance_create_info, nil, &instance); res != .SUCCESS {
        log.panicf("Failed to create Vulkan instance! Error: {}\n", res)
    }
    defer vk.DestroyInstance(instance, nil)
    vk.load_proc_addresses_instance(instance)

    // @Note(Daniel): Create debug messenger
    when ENABLE_VALIDATION {
        debug_messenger : vk.DebugUtilsMessengerEXT
        debug_messenger_create_info := create_debug_messenger_create_info()
        vk.CreateDebugUtilsMessengerEXT(instance, &debug_messenger_create_info, nil, &debug_messenger)
    }
    defer when ENABLE_VALIDATION {
        vk.DestroyDebugUtilsMessengerEXT(instance, debug_messenger, nil)
    }

    // @Note(Daniel): Create window surface
    window_surface : vk.SurfaceKHR
    if res := glfw.CreateWindowSurface(instance, window, nil, &window_surface); res != .SUCCESS {
        log.panicf("Failed to create window surface! Error: {}\n", res)
    }
    defer vk.DestroySurfaceKHR(instance, window_surface, nil)

    // @Note(Daniel): Get physical device candidates
    available_physical_device_count : u32
    vk.EnumeratePhysicalDevices(instance, &available_physical_device_count, nil)
    if available_physical_device_count == 0 {
        log.panicf("No physical device with Vulkan support found!\n")
    }
    available_physical_devices := make([]vk.PhysicalDevice, available_physical_device_count)
    vk.EnumeratePhysicalDevices(instance, &available_physical_device_count, raw_data(available_physical_devices))

    required_device_extensions := []cstring {
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
    }

    Device_Candidate :: struct { device : vk.PhysicalDevice, score : int }
    device_candidates : [dynamic]Device_Candidate
    for device in available_physical_devices {
        // device_props    : vk.PhysicalDeviceProperties
        // device_features : vk.PhysicalDeviceFeatures
        // vk.GetPhysicalDeviceProperties(device, &device_props)
        // vk.GetPhysicalDeviceFeatures(device, &device_features)

        // if device_props.deviceType == .DISCRETE_GPU { score += 1000 }
        // score += cast(int) device_props.limits.maxImageDimension2D
        // if !device_features.geometryShader { score = 0 }

        // @Note(Daniel): Get required device extensions
        available_device_extension_count : u32
        vk.EnumerateDeviceExtensionProperties(device, nil, &available_device_extension_count, nil)
        available_device_extensions := make([]vk.ExtensionProperties, available_device_extension_count)
        defer delete(available_device_extensions)
        vk.EnumerateDeviceExtensionProperties(device, nil, &available_device_extension_count, raw_data(available_device_extensions))

        queue_family_indices := find_queue_families(device, window_surface)
        score : int
        if queue_family_indices.graphics     != nil { score += 1 }
        if queue_family_indices.presentation != nil { score += 1 }

        for needed_ext in required_device_extensions {
            ext_found := false
            for ext in &available_device_extensions {
                ext_name := strings.trim_null(string(ext.extensionName[:]))
                if string(needed_ext) == ext_name {
                    ext_found = true
                    break
                }
            }

            if !ext_found {
                score = 0
            }
        }

        if score != 0 {
            swapchain_available := get_swapchain_available_support(device, window_surface)

            if len(swapchain_available.surface_formats) <= 0 { score = 0 }
            if len(swapchain_available.present_modes  ) <= 0 { score = 0 }
        }

        append(&device_candidates, Device_Candidate { device = device, score = score })
    }

    slice.sort_by(
        data = device_candidates[:],
        less = proc(i, j : Device_Candidate) -> bool { return i.score > j.score },
    )

    // @Note(Daniel): Select physical device to use
    physical_device : vk.PhysicalDevice
    if device_candidates[0].score > 0 {
        physical_device = device_candidates[0].device
    }
    else {
        log.panicf("Failed to find a suitable GPU!\n")
    }

    {
        device_props : vk.PhysicalDeviceProperties
        vk.GetPhysicalDeviceProperties(physical_device, &device_props)
        device_name := strings.trim_null(string(device_props.deviceName[:]))

        available_device_extension_count : u32
        vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_device_extension_count, nil)
        available_device_extensions := make([]vk.ExtensionProperties, available_device_extension_count)
        defer delete(available_device_extensions)
        vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_device_extension_count, raw_data(available_device_extensions))

        log.infof("Physical device chosen: {} ({})\n", device_name, device_props.deviceID)
        log.debug("Specified required extensions available:\n")
        for ext in &available_device_extensions {
            ext_name := strings.trim_null(string(ext.extensionName[:]))
            for needed_ext in required_device_extensions {
                if string(needed_ext) == ext_name {
                    log.debugf("    {}\n", ext_name)
                }
            }
        }
    }

    // @Note(Daniel): Create queues
    queue_family_indices  := find_queue_families(physical_device, window_surface)
    unique_queue_families := [?]u32 {
        queue_family_indices.graphics.?,
        queue_family_indices.presentation.?,
    }

    queue_create_infos : [len(unique_queue_families)]vk.DeviceQueueCreateInfo
    queue_priority : f32 = 1.0
    for queue_family_index, i in unique_queue_families {
        create_info := vk.DeviceQueueCreateInfo {
            sType            = .DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = queue_family_index,
            pQueuePriorities = &queue_priority,
            queueCount       = 1,
        }
        queue_create_infos[i] = create_info
    }

    // @Note(Daniel): Get device features to use
    physical_device_features : vk.PhysicalDeviceFeatures

    // @Note(Daniel): Create logical device
    logical_device_create_info := vk.DeviceCreateInfo {
        sType                   = .DEVICE_CREATE_INFO,
        queueCreateInfoCount    = auto_cast len(queue_create_infos),
        pQueueCreateInfos       = raw_data(queue_create_infos[:]),
        pEnabledFeatures        = &physical_device_features,
        enabledExtensionCount   = auto_cast len(required_device_extensions),
        ppEnabledExtensionNames = raw_data(required_device_extensions),

        // @Note(Daniel): Not necessary anymore, but for compatibility with older Vulkan implementations we set these anyway
        enabledLayerCount       = auto_cast len(validation_layers) when ENABLE_VALIDATION else 0,
        ppEnabledLayerNames     = raw_data(validation_layers)      when ENABLE_VALIDATION else nil,
    }

    logical_device : vk.Device
    if res := vk.CreateDevice(physical_device, &logical_device_create_info, nil, &logical_device); res != .SUCCESS {
        log.panicf("Failed to create logical device! Error: {}\n", res)
    }
    defer vk.DestroyDevice(logical_device, nil)

    // @Note(Daniel): Retrieve queue handles
    graphics_queue, presentation_queue : vk.Queue
    vk.GetDeviceQueue(logical_device, queue_family_indices.graphics.?,     0, &graphics_queue)
    vk.GetDeviceQueue(logical_device, queue_family_indices.presentation.?, 0, &presentation_queue)

    // @Note(Daniel): Create swapchain
    swapchain_available := get_swapchain_available_support(physical_device, window_surface)

    swapchain_surface_format : vk.SurfaceFormatKHR
    for format in swapchain_available.surface_formats {
        if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
            swapchain_surface_format = format
            break
        }
    }

    swapchain_present_mode : vk.PresentModeKHR
    for mode in swapchain_available.present_modes {
        if mode == .MAILBOX {
            swapchain_present_mode = mode
            break
        }
        swapchain_present_mode = .FIFO
    }

    swapchain_extents : vk.Extent2D
    if swapchain_available.capabilities.currentExtent.width != max(u32) {
        swapchain_extents = swapchain_available.capabilities.currentExtent
    }
    else {
        using swapchain_available.capabilities
        width, height := glfw.GetFramebufferSize(window)
        swapchain_extents = {
            width  = clamp(cast(u32) width,  minImageExtent.width,  maxImageExtent.width),
            height = clamp(cast(u32) height, minImageExtent.height, maxImageExtent.height),
        }
    }

    swapchain_min_image_count := swapchain_available.capabilities.minImageCount + 1
    if swapchain_available.capabilities.maxImageCount > 0 && swapchain_min_image_count > swapchain_available.capabilities.maxImageCount {
        swapchain_min_image_count = swapchain_available.capabilities.maxImageCount
    }

    shared_queue_family_indices := (queue_family_indices.graphics.? == queue_family_indices.presentation.?)
    swapchain_create_info := vk.SwapchainCreateInfoKHR {
        sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
        surface               = window_surface,
        imageFormat           = swapchain_surface_format.format,
        imageColorSpace       = swapchain_surface_format.colorSpace,
        presentMode           = swapchain_present_mode,
        imageExtent           = swapchain_extents,
        minImageCount         = swapchain_min_image_count,

        imageArrayLayers      = 1,
        preTransform          = swapchain_available.capabilities.currentTransform,
        imageUsage            = { .COLOR_ATTACHMENT },
        compositeAlpha        = { .OPAQUE },
        clipped               = true,
        oldSwapchain          = vk.SwapchainKHR(0),

        imageSharingMode      =  .CONCURRENT                          if !shared_queue_family_indices else .EXCLUSIVE,
        queueFamilyIndexCount =  auto_cast len(unique_queue_families) if !shared_queue_family_indices else 0,
        pQueueFamilyIndices   =  raw_data(unique_queue_families[:])   if !shared_queue_family_indices else nil,
    }

    swapchain : vk.SwapchainKHR
    if res := vk.CreateSwapchainKHR(logical_device, &swapchain_create_info, nil, &swapchain); res != .SUCCESS {
        log.panicf("Failed to create swapchain! Error: {}\n", res)
    }
    defer vk.DestroySwapchainKHR(logical_device, swapchain, nil)

    swapchain_image_count : u32
    vk.GetSwapchainImagesKHR(logical_device, swapchain, &swapchain_image_count, nil)
    swapchain_images      := make([]vk.Image,     swapchain_image_count)
    swapchain_image_views := make([]vk.ImageView, swapchain_image_count)
    vk.GetSwapchainImagesKHR(logical_device, swapchain, &swapchain_image_count, raw_data(swapchain_images))
    for image, i in swapchain_images {
        view_create_info := vk.ImageViewCreateInfo {
            sType            = .IMAGE_VIEW_CREATE_INFO,
            image            = image,
            viewType         = .D2,
            format           = swapchain_surface_format.format,
            components       = {
                r = .IDENTITY,
                g = .IDENTITY,
                b = .IDENTITY,
                a = .IDENTITY,
            },
            subresourceRange = {
                aspectMask     = { .COLOR },
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1,
            },
        }

        if res := vk.CreateImageView(logical_device, &view_create_info, nil, &swapchain_image_views[i]); res != .SUCCESS {
            log.panicf("Failed to create image view #{}! Error: {}", i, res)
        }
    }
    defer for view in swapchain_image_views {
        vk.DestroyImageView(logical_device, view, nil)
    }

    // @Note(Daniel): Main loop
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents();
    }
}

Queue_Family_Indices :: struct {
    graphics,
    presentation : Maybe(u32),
}

Swapchain_Available_Support :: struct {
    capabilities    : vk.SurfaceCapabilitiesKHR,
    surface_formats : []vk.SurfaceFormatKHR,
    present_modes   : []vk.PresentModeKHR,
}

create_debug_messenger_create_info :: proc() -> vk.DebugUtilsMessengerCreateInfoEXT {
    debug_callback :: proc "system" (
        message_severity   : vk.DebugUtilsMessageSeverityFlagsEXT,
        message_type_flags : vk.DebugUtilsMessageTypeFlagsEXT,
        callback_data      : ^vk.DebugUtilsMessengerCallbackDataEXT,
        user_data          : rawptr,
    ) -> b32 {
        context = g_context
        if callback_data.messageIdNumber == 0xde3cbaf { return false }

        format_str := fmt.tprintf("Validation{{}}: {}\n", callback_data.pMessage)

        switch {
            case message_severity >= { .ERROR }:   log.errorf(format_str, " Error")
            case message_severity >= { .WARNING }: log.warnf(format_str, " Warning")
            case:                                  log.debugf(format_str, "")
        }

        return false
    }

    return {
        sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        messageSeverity = { .VERBOSE, .WARNING, .ERROR },
        messageType     = { .GENERAL, .VALIDATION, .PERFORMANCE },
        pfnUserCallback = debug_callback,
        pUserData       = nil,
    }
}

find_queue_families :: proc(device : vk.PhysicalDevice, surface : vk.SurfaceKHR) -> (queue_family_indices : Queue_Family_Indices) {
    available_queue_family_count : u32
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &available_queue_family_count, nil)
    available_queue_families := make([]vk.QueueFamilyProperties, available_queue_family_count)
    defer delete(available_queue_families)
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &available_queue_family_count, raw_data(available_queue_families))

    for queue_family, index in available_queue_families {
        present_support : b32
        vk.GetPhysicalDeviceSurfaceSupportKHR(device, auto_cast index, surface, &present_support)
        if present_support {
            queue_family_indices.presentation = cast(u32) index
        }

        if queue_family.queueFlags >= { .GRAPHICS } {
            queue_family_indices.graphics = cast(u32) index
            break
        }
    }

    return
}

get_swapchain_available_support :: proc(device : vk.PhysicalDevice, surface : vk.SurfaceKHR) -> (swapchain_available : Swapchain_Available_Support) {
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &swapchain_available.capabilities)

    available_surface_format_count : u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &available_surface_format_count, nil)
    swapchain_available.surface_formats = make([]vk.SurfaceFormatKHR, available_surface_format_count)
    vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &available_surface_format_count, raw_data(swapchain_available.surface_formats))

    available_present_mode_count : u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &available_present_mode_count, nil)
    swapchain_available.present_modes = make([]vk.PresentModeKHR, available_present_mode_count)
    vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &available_present_mode_count, raw_data(swapchain_available.present_modes))

    return
}
