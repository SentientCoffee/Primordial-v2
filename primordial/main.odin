package primordial

import "core:c"
import "core:fmt"
import "core:intrinsics"
import "core:log"
import "core:math/linalg"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"

when ODIN_OS == .Windows {
    import win32 "core:sys/windows"
}

import "vendor:glfw"
import vk "vendor:vulkan"

import "shared:set_of"

WIDTH  :: 800
HEIGHT :: 600
TITLE  :: "Vulkan"

MAX_FRAMES_IN_FLIGHT :: 2

when ODIN_DEBUG { ENABLE_VALIDATION :: true  }
else            { ENABLE_VALIDATION :: false }

when ODIN_DEBUG {
    import "core:mem"
    main :: proc() {
        context = setup_context()

        track : mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        _main()

        for _, leak in track.allocation_map {
            log.warnf("[{}:{}:{}] Leaked {} bytes", leak.location.file_path, leak.location.line, leak.location.column, leak.size)
        }
        for bad_free in track.bad_free_array {
            log.warnf("[{}:{}:{}] Allocation {:p} was freed badly", bad_free.location.file_path, bad_free.location.line, bad_free.location.column, bad_free.memory)
        }
    }
}
else {
    main :: proc() {
        context = setup_context()
        _main()
    }
}

framebuffer_resized := false

_main :: proc() {
    // @Note(Daniel): Init window
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, 1)

    window := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)
    defer glfw.DestroyWindow(window);

    log.debugf("Created window \"{}\" ({}x{})", TITLE, WIDTH, HEIGHT)

    glfw.SetFramebufferSizeCallback(window, proc "c" (window : glfw.WindowHandle, width, height : c.int) {
        // @Todo(Daniel): Don't use globals for this
        framebuffer_resized = true
    })
    log.debug("Set window framebuffer size callback")

    // @Note(Daniel): Load Vulkan global procs
    // @Reference: https://gist.github.com/terickson001/bdaa52ce621a6c7f4120abba8959ffe6#file-main-odin-L216
    vk.load_proc_addresses_global(cast(rawptr) glfw.GetInstanceProcAddress)
    log.debug("Loaded global Vulkan proc addresses")

    // @Note(Daniel): Get required instance extensions
    available_instance_extension_count : u32
    vk.EnumerateInstanceExtensionProperties(nil, &available_instance_extension_count, nil)
    available_instance_extensions := make([]vk.ExtensionProperties, available_instance_extension_count)
    defer delete(available_instance_extensions)
    vk.EnumerateInstanceExtensionProperties(nil, &available_instance_extension_count, raw_data(available_instance_extensions))

    glfw_required_extensions       := glfw.GetRequiredInstanceExtensions()
    available_glfw_extension_count := 0
    for ext in &available_instance_extensions {
        ext_name := string(cstring(raw_data(ext.extensionName[:])))
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
    defer delete(required_extensions)

    // @Note(Daniel): Get validation layers
    when ENABLE_VALIDATION {
        validation_layers := []cstring {
            "VK_LAYER_KHRONOS_validation",
        }

        available_layer_count : u32
        vk.EnumerateInstanceLayerProperties(&available_layer_count, nil)
        available_layers := make([]vk.LayerProperties, available_layer_count)
        defer delete(available_layers)
        vk.EnumerateInstanceLayerProperties(&available_layer_count, raw_data(available_layers))

        for needed_layer in validation_layers {
            layer_found := false

            for layer_props in &available_layers {
                layer_name := string(cstring(raw_data(layer_props.layerName[:])))
                if string(needed_layer) == layer_name {
                    layer_found = true
                    break
                }
            }

            if !layer_found {
                log.panicf("Requested validation layer \"{}\" not in available layers!", needed_layer)
            }
        }

        log.infof("Validation layers enabled")
    }

    // @Note(Daniel): Create Vulkan instance
    when ENABLE_VALIDATION {
        instance_debug_messenger_create_info := debug_messenger_create_info_create()
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
        log.panicf("Failed to create Vulkan instance! Error: {}", res)
    }
    defer vk.DestroyInstance(instance, nil)
    log.debug("Created new Vulkan instance")
    vk.load_proc_addresses_instance(instance)
    log.debug("Loaded instance-specific Vulkan proc addresses")

    // @Note(Daniel): Create debug messenger
    when ENABLE_VALIDATION {
        debug_messenger : vk.DebugUtilsMessengerEXT
        debug_messenger_create_info := debug_messenger_create_info_create()
        vk.CreateDebugUtilsMessengerEXT(instance, &debug_messenger_create_info, nil, &debug_messenger)
        log.debug("Created debug messenger")
    }
    defer when ENABLE_VALIDATION {
        vk.DestroyDebugUtilsMessengerEXT(instance, debug_messenger, nil)
    }

    // @Note(Daniel): Create window surface
    window_surface : vk.SurfaceKHR
    if res := glfw.CreateWindowSurface(instance, window, nil, &window_surface); res != .SUCCESS {
        log.panicf("Failed to create window surface! Error: {}", res)
    }
    defer vk.DestroySurfaceKHR(instance, window_surface, nil)
    log.debug("Created window surface")

    // @Note(Daniel): Get physical device candidates
    available_physical_device_count : u32
    vk.EnumeratePhysicalDevices(instance, &available_physical_device_count, nil)
    if available_physical_device_count == 0 {
        log.panicf("No physical device with Vulkan support found!")
    }
    available_physical_devices := make([]vk.PhysicalDevice, available_physical_device_count)
    defer delete(available_physical_devices)
    vk.EnumeratePhysicalDevices(instance, &available_physical_device_count, raw_data(available_physical_devices))

    required_device_extensions := []cstring {
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
    }

    Device_Candidate :: struct { device : vk.PhysicalDevice, score : int }
    device_candidates : [dynamic]Device_Candidate
    defer delete(device_candidates)
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
                ext_name := string(cstring(raw_data(ext.extensionName[:])))
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
            swapchain_available := swapchain_available_support_make(device, window_surface)
            defer swapchain_available_support_delete(swapchain_available)

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
        log.panicf("Failed to find a suitable GPU!")
    }

    {
        device_props : vk.PhysicalDeviceProperties
        vk.GetPhysicalDeviceProperties(physical_device, &device_props)
        device_name := string(cstring(raw_data(device_props.deviceName[:])))

        available_device_extension_count : u32
        vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_device_extension_count, nil)
        available_device_extensions := make([]vk.ExtensionProperties, available_device_extension_count)
        defer delete(available_device_extensions)
        vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_device_extension_count, raw_data(available_device_extensions))

        log.infof("Physical device chosen: {} ({})", device_name, device_props.deviceID)
        log.debug("Specified required extensions available:")
        for ext in &available_device_extensions {
            ext_name := string(cstring(raw_data(ext.extensionName[:])))
            for needed_ext in required_device_extensions {
                if string(needed_ext) == ext_name {
                    log.debugf("    -- {}", ext_name)
                }
            }
        }
    }

    // @Note(Daniel): Create queues
    queue_family_indices := find_queue_families(physical_device, window_surface)

    unique_queue_families := set_of.make_set_of(u32)
    defer set_of.delete_set(unique_queue_families)
    set_of.add(&unique_queue_families, queue_family_indices.graphics.?)
    set_of.add(&unique_queue_families, queue_family_indices.presentation.?)

    queue_create_infos := make([]vk.DeviceQueueCreateInfo, set_of.length(unique_queue_families))
    defer delete(queue_create_infos)
    {
        it := set_of.iterator_create(unique_queue_families)
        for queue_family_index, i in set_of.iterate(&it) {
            queue_priority : f32 = 1.0
            create_info := vk.DeviceQueueCreateInfo {
                sType            = .DEVICE_QUEUE_CREATE_INFO,
                queueFamilyIndex = queue_family_index,
                pQueuePriorities = &queue_priority,
                queueCount       = 1,
            }
            queue_create_infos[i] = create_info
        }
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
        log.panicf("Failed to create logical device! Error: {}", res)
    }
    defer vk.DestroyDevice(logical_device, nil)
    log.debug("Created logical device")

    // @Note(Daniel): Retrieve queue handles
    graphics_queue, presentation_queue : vk.Queue
    vk.GetDeviceQueue(logical_device, queue_family_indices.graphics.?,     0, &graphics_queue)
    vk.GetDeviceQueue(logical_device, queue_family_indices.presentation.?, 0, &presentation_queue)

    // @Note(Daniel): Create shader modules
    VERT_SHADER_PATH :: "build/shader_cache/triangle.glsl/triangle.glsl.vert.spv"
    FRAG_SHADER_PATH :: "build/shader_cache/triangle.glsl/triangle.glsl.frag.spv"

    // Vertex shader
    vert_shader_src, read_vert_ok := os.read_entire_file(VERT_SHADER_PATH)
    defer delete(vert_shader_src)
    if !read_vert_ok {
        log.panicf("Failed to read vertex shader source from \"{}\"!", VERT_SHADER_PATH)
    }
    vert_shader_module_create_info := vk.ShaderModuleCreateInfo {
        sType    = .SHADER_MODULE_CREATE_INFO,
        codeSize = len(vert_shader_src),
        pCode    = cast(^u32) raw_data(vert_shader_src),
    }
    vert_shader_module : vk.ShaderModule
    if res := vk.CreateShaderModule(logical_device, &vert_shader_module_create_info, nil, &vert_shader_module); res != .SUCCESS {
        log.errorf("Failed to create vertex shader module from path \"{}\"!", VERT_SHADER_PATH)
        log.panicf("    Error: {}", res)
    }
    vert_shader_stage_create_info := vk.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage  = { .VERTEX },
        module = vert_shader_module,
        pName  = "main",
    }
    defer vk.DestroyShaderModule(logical_device, vert_shader_module, nil)
    log.debugf("Created vertex shader module from \"{}\"", VERT_SHADER_PATH)

    // Fragment shader
    frag_shader_src, read_frag_ok := os.read_entire_file(FRAG_SHADER_PATH)
    defer delete(frag_shader_src)
    if !read_frag_ok {
        log.panicf("Failed to read fragment shader source from \"{}\"!", FRAG_SHADER_PATH)
    }
    frag_shader_module_create_info := vk.ShaderModuleCreateInfo {
        sType    = .SHADER_MODULE_CREATE_INFO,
        codeSize = len(frag_shader_src),
        pCode    = cast(^u32) raw_data(frag_shader_src),
    }
    frag_shader_module : vk.ShaderModule
    if res := vk.CreateShaderModule(logical_device, &frag_shader_module_create_info, nil, &frag_shader_module); res != .SUCCESS {
        log.errorf("Failed to create fragment shader module from path \"{}\"!", FRAG_SHADER_PATH)
        log.panicf("    Error: {}", res)
    }
    frag_shader_stage_create_info := vk.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage  = { .FRAGMENT },
        module = frag_shader_module,
        pName  = "main",
    }
    defer vk.DestroyShaderModule(logical_device, frag_shader_module, nil)
    log.debugf("Created fragment shader module from \"{}\"", FRAG_SHADER_PATH)

    pipeline_shader_stages := [?]vk.PipelineShaderStageCreateInfo { vert_shader_stage_create_info, frag_shader_stage_create_info }

    // @Note(Daniel): Graphics pipeline fixed function state

    // Dynamic states (can be changed at render time, not immutable)
    dynamic_states := [?]vk.DynamicState { .VIEWPORT, .SCISSOR }
    dynamic_state_create_info := vk.PipelineDynamicStateCreateInfo {
        sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        dynamicStateCount = len(dynamic_states),
        pDynamicStates    = raw_data(&dynamic_states),
    }

    // Vertex input
    vert_binding_desc := vk.VertexInputBindingDescription {
        binding   = 0,
        stride    = size_of(Vertex),
        inputRate = .VERTEX,
    }

    vert_attribute_descs := [2]vk.VertexInputAttributeDescription {
        {
            binding  = 0,
            location = 0,
            format   = .R32G32_SFLOAT,
            offset   = cast(u32) offset_of(Vertex, position),
        },
        {
            binding  = 0,
            location = 1,
            format   = .R32G32B32_SFLOAT,
            offset   = cast(u32) offset_of(Vertex, color),
        },
    }

    vert_input_create_info := vk.PipelineVertexInputStateCreateInfo {
        sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount   = 1,
        pVertexBindingDescriptions      = &vert_binding_desc,
        vertexAttributeDescriptionCount = len(vert_attribute_descs),
        pVertexAttributeDescriptions    = raw_data(&vert_attribute_descs),
    }
    input_assembly_create_info := vk.PipelineInputAssemblyStateCreateInfo {
        sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology               = .TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    viewport_state_create_info := vk.PipelineViewportStateCreateInfo {
        sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        scissorCount  = 1,
        // Will be set up as part of dynamic state
        pViewports    = nil,
        pScissors     = nil,
    }

    // Rasterizer
    rasterization_state_create_info := vk.PipelineRasterizationStateCreateInfo {
        sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthClampEnable        = false,
        rasterizerDiscardEnable = false,
        polygonMode             = .FILL,
        lineWidth               = 1.0,
        cullMode                = { .BACK },
        frontFace               = .CLOCKWISE,
        depthBiasEnable         = false,
    }

    // Multisampling
    multisample_state_create_info := vk.PipelineMultisampleStateCreateInfo {
        sType                 = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable   = false,
        rasterizationSamples  = { ._1 },
        minSampleShading      = 1.0,
        pSampleMask           = nil,
        alphaToCoverageEnable = false,
        alphaToOneEnable      = false,
    }

    // Per-attachement color blending
    color_blend_attachment_state := vk.PipelineColorBlendAttachmentState {
        colorWriteMask      = { .R, .G, .B, .A },
        blendEnable         = false,
        srcColorBlendFactor = .ONE,
        dstColorBlendFactor = .ZERO,
        colorBlendOp        = .ADD,
        srcAlphaBlendFactor = .ONE,
        dstAlphaBlendFactor = .ZERO,
        alphaBlendOp        = .ADD,
    }

    // Global color blending
    color_blend_state_create_info := vk.PipelineColorBlendStateCreateInfo {
        sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        logicOpEnable   = false,
        logicOp         = .COPY,
        attachmentCount = 1,
        pAttachments    = &color_blend_attachment_state,
        blendConstants  = { 0.0, 0.0, 0.0, 0.0 },
    }

    // @Note(Daniel): Pipeline layout (uniforms/push constants)
    pipeline_layout_create_info := vk.PipelineLayoutCreateInfo {
        sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount         = 0,
        pSetLayouts            = nil,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = nil,
    }
    pipeline_layout : vk.PipelineLayout
    if res := vk.CreatePipelineLayout(logical_device, &pipeline_layout_create_info, nil, &pipeline_layout); res != .SUCCESS {
        log.panicf("Failed to create pipeline layout! Error: {}", res)
    }
    defer vk.DestroyPipelineLayout(logical_device, pipeline_layout, nil)
    log.debug("Created pipeline layout")

    // @Note(Daniel): Create render pass

    // Query swapchain capabilities
    swapchain_available := swapchain_available_support_make(physical_device, window_surface)
    defer swapchain_available_support_delete(swapchain_available)

    // Choose surface format
    surface_format : vk.SurfaceFormatKHR
    for format in swapchain_available.surface_formats {
        if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
            surface_format = format
            break
        }
    }

    // Color attachments
    color_attachment_desc := vk.AttachmentDescription {
        format         = surface_format.format,
        samples        = { ._1 },
        loadOp         = .CLEAR,
        storeOp        = .STORE,
        stencilLoadOp  = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout  = .UNDEFINED,
        finalLayout    = .PRESENT_SRC_KHR,
    }
    color_attachment_reference := vk.AttachmentReference {
        attachment = 0,    // Will reference the attachment at index 0 (also used by the fragment shader using `layout(location = 0)`)
        layout     = .COLOR_ATTACHMENT_OPTIMAL,
    }

    // Subpass
    subpass_desc := vk.SubpassDescription {
        pipelineBindPoint    = .GRAPHICS,
        colorAttachmentCount = 1,
        pColorAttachments    = &color_attachment_reference,
    }
    subpass_dependency := vk.SubpassDependency {
        srcSubpass    = vk.SUBPASS_EXTERNAL,            // Defined to be the implicit subpass before the first defined subpass, where we ensure we have the image from the swapchain before we render
        dstSubpass    = 0,                              // Subpass at index 0, defined earlier
        srcStageMask  = { .COLOR_ATTACHMENT_OUTPUT },
        srcAccessMask = {},
        dstStageMask  = { .COLOR_ATTACHMENT_OUTPUT },
        dstAccessMask = { .COLOR_ATTACHMENT_WRITE },
    }

    // Final render pass
    render_pass_create_info := vk.RenderPassCreateInfo {
        sType           = .RENDER_PASS_CREATE_INFO,
        attachmentCount = 1,
        pAttachments    = &color_attachment_desc,
        subpassCount    = 1,
        pSubpasses      = &subpass_desc,
        dependencyCount = 1,
        pDependencies   = &subpass_dependency,
    }
    render_pass : vk.RenderPass
    if res := vk.CreateRenderPass(logical_device, &render_pass_create_info, nil, &render_pass); res != .SUCCESS {
        log.panicf("Failed to create render pass! Error: {}", res)
    }
    defer vk.DestroyRenderPass(logical_device, render_pass, nil)
    log.debug("Created render pass")

    // @Note(Daniel): Create swapchain
    swapchain := swapchain_make(window, window_surface, surface_format, physical_device, logical_device, render_pass)
    defer swapchain_delete(logical_device, swapchain)

    // @Note(Daniel): Create final graphics pipeline
    graphics_pipeline_create_info := vk.GraphicsPipelineCreateInfo {
        sType               = .GRAPHICS_PIPELINE_CREATE_INFO,

        // Shader stages
        stageCount          = cast(u32) len(pipeline_shader_stages),
        pStages             = raw_data(&pipeline_shader_stages),

        // Fixed function state
        pDynamicState       = &dynamic_state_create_info,
        pVertexInputState   = &vert_input_create_info,
        pViewportState      = &viewport_state_create_info,
        pInputAssemblyState = &input_assembly_create_info,
        pRasterizationState = &rasterization_state_create_info,
        pMultisampleState   = &multisample_state_create_info,
        pColorBlendState    = &color_blend_state_create_info,
        pDepthStencilState  = nil,

        // Layout and render pass
        layout     = pipeline_layout,
        renderPass = render_pass,
        subpass    = 0,
    }

    graphics_pipeline : vk.Pipeline
    if res := vk.CreateGraphicsPipelines(
        device          = logical_device,
        pipelineCache   = /*vk.NULL_HANDLE*/{},
        createInfoCount = 1,
        pCreateInfos    = &graphics_pipeline_create_info,
        pAllocator      = nil,
        pPipelines      = &graphics_pipeline,
    ); res != .SUCCESS {
        log.panicf("Failed to create graphics pipeline! Error: {}", res)
    }
    defer vk.DestroyPipeline(logical_device, graphics_pipeline, nil)
    log.debug("Created graphics pipeline")
    {
        log.debugf("    -- Shader stages: {}", len(pipeline_shader_stages))
        // @Todo(Daniel): File a bug for this?
        // for stage, i in graphics_pipeline_create_info.pStages[:graphics_pipeline_create_info.stageCount] {
        //     log.debugf("        -- {}: {}", i, stage)
        // }
        log.debugf("    -- Dynamic states: {}", dynamic_states)
        log.debugf("    -- Viewports: {}, scissors: {}", viewport_state_create_info.viewportCount, viewport_state_create_info.scissorCount)
        log.debugf("    -- Subpasses: {} ({} total attachment(s))", render_pass_create_info.subpassCount, render_pass_create_info.attachmentCount)
        for subpass, i in render_pass_create_info.pSubpasses[:render_pass_create_info.subpassCount] {
            log.debugf("        -- {}: {} ({} color attachment(s))", i, subpass.pipelineBindPoint, subpass.colorAttachmentCount)
        }
    }

    // @Note(Daniel): Create command pool
    command_pool_create_info := vk.CommandPoolCreateInfo {
        sType            = .COMMAND_POOL_CREATE_INFO,
        flags            = { .RESET_COMMAND_BUFFER },
        queueFamilyIndex = queue_family_indices.graphics.?,
    }
    command_pool : vk.CommandPool
    if res := vk.CreateCommandPool(logical_device, &command_pool_create_info, nil, &command_pool); res != .SUCCESS {
        log.panicf("Failed to create command pool! Error: {}", res)
    }
    defer vk.DestroyCommandPool(logical_device, command_pool, nil)
    log.debug("Created command pool")

    // @Note(Daniel): Create vertex buffer
    vertices := [?]Vertex {
        { position = {  0.0, -0.5 }, color = { 1.0, 0.0, 0.0 } },
        { position = {  0.5,  0.5 }, color = { 0.0, 1.0, 0.0 } },
        { position = { -0.5,  0.5 }, color = { 0.0, 0.0, 1.0 } },
    }

    vertex_buffer_create_info := vk.BufferCreateInfo {
        sType       = .BUFFER_CREATE_INFO,
        size        = size_of(Vertex) * len(vertices),
        usage       = { .VERTEX_BUFFER },
        sharingMode = .EXCLUSIVE,
    }
    vertex_buffer : vk.Buffer
    if res := vk.CreateBuffer(logical_device, &vertex_buffer_create_info, nil, &vertex_buffer); res != .SUCCESS {
        log.panicf("Failed to create vertex buffer! Error: {}", res)
    }
    log.debugf("Created vertex buffer with {} vertices ({} bytes)", len(vertices), vertex_buffer_create_info.size)

    vertex_buffer_memory_requirements : vk.MemoryRequirements
    physical_device_memory_properties : vk.PhysicalDeviceMemoryProperties
    vk.GetBufferMemoryRequirements(logical_device, vertex_buffer, &vertex_buffer_memory_requirements)
    vk.GetPhysicalDeviceMemoryProperties(physical_device, &physical_device_memory_properties)

    vertex_buffer_memory_type_index : u32
    for t, i in physical_device_memory_properties.memoryTypes[:physical_device_memory_properties.memoryTypeCount] {
        idx := cast(u32) i
        is_compatible_memory_type  := (vertex_buffer_memory_requirements.memoryTypeBits & (1 << idx)) != 0
        supports_memory_properties := t.propertyFlags >= { .HOST_VISIBLE, .HOST_COHERENT }
        if is_compatible_memory_type && supports_memory_properties {
            vertex_buffer_memory_type_index = idx
            break
        }
    }

    vertex_buffer_memory_alloc_info := vk.MemoryAllocateInfo {
        sType = .MEMORY_ALLOCATE_INFO,
        allocationSize = vertex_buffer_memory_requirements.size,
        memoryTypeIndex = vertex_buffer_memory_type_index,
    }
    vertex_buffer_memory : vk.DeviceMemory
    if res := vk.AllocateMemory(logical_device, &vertex_buffer_memory_alloc_info, nil, &vertex_buffer_memory); res != .SUCCESS {
        log.panicf("Failed to allocate vertex buffer memory! Error: {}", res)
    }
    log.debugf("Allocated {} bytes for vertex buffer", vertex_buffer_memory_alloc_info.allocationSize)
    vk.BindBufferMemory(logical_device, vertex_buffer, vertex_buffer_memory, 0)

    defer {
        // @Note(Daniel): Need to free the memory AFTER the vertex buffer is destroyed
        vk.DestroyBuffer(logical_device, vertex_buffer, nil)
        vk.FreeMemory(logical_device, vertex_buffer_memory, nil)
    }

    // @Note(Daniel): Fill the vertex buffer
    vertex_buffer_gpu_data : rawptr
    vk.MapMemory(logical_device, vertex_buffer_memory, 0, vertex_buffer_create_info.size, {}, &vertex_buffer_gpu_data)
    mem.copy(vertex_buffer_gpu_data, raw_data(&vertices), cast(int) vertex_buffer_create_info.size)
    log.debugf("Copied {} bytes to vertex buffer", vertex_buffer_create_info.size)
    vk.UnmapMemory(logical_device, vertex_buffer_memory)

    // @Note(Daniel): Allocate command buffer
    command_buffer_alloc_info := vk.CommandBufferAllocateInfo {
        sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool        = command_pool,
        level              = .PRIMARY,
        commandBufferCount = MAX_FRAMES_IN_FLIGHT,
    }
    command_buffers : [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer
    if res := vk.AllocateCommandBuffers(logical_device, &command_buffer_alloc_info, raw_data(&command_buffers)); res != .SUCCESS {
        log.panicf("Failed to allocate command buffer(s)! Error: {}", res)
    }
    log.debugf("Allocated {} command buffer(s)", command_buffer_alloc_info.commandBufferCount)

    // @Note(Daniel): Create synchronization objects
    semaphore_create_info := vk.SemaphoreCreateInfo {
        sType = .SEMAPHORE_CREATE_INFO,
    }
    fence_create_info := vk.FenceCreateInfo {
        sType = .FENCE_CREATE_INFO,
        flags = { .SIGNALED },
    }
    swapchain_image_available_sems, render_finished_sems : [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
    in_flight_fences : [MAX_FRAMES_IN_FLIGHT]vk.Fence
    for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
        image_avail_res   := vk.CreateSemaphore(logical_device, &semaphore_create_info, nil, &swapchain_image_available_sems[i]);
        render_finish_res := vk.CreateSemaphore(logical_device, &semaphore_create_info, nil, &render_finished_sems[i]);
        in_flight_res     := vk.CreateFence(logical_device, &fence_create_info, nil, &in_flight_fences[i]);
        if image_avail_res != .SUCCESS || render_finish_res != .SUCCESS || in_flight_res != .SUCCESS {
            log.error("Failed to create sync objects!")
            log.panicf("    {}: Image available semaphore: {} | Render finished semaphore: {} | In-flight fence: {}", i, image_avail_res, render_finish_res, in_flight_res)
        }
    }
    defer for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
        vk.DestroySemaphore(logical_device, swapchain_image_available_sems[i], nil)
        vk.DestroySemaphore(logical_device, render_finished_sems[i], nil)
        vk.DestroyFence(logical_device, in_flight_fences[i], nil)
    }
    log.debug("Created sync objects")

    // @Note(Daniel): Main loop
    current_frame_index := 0
    for !glfw.WindowShouldClose(window) {
        // @Note(Daniel): Poll input events
        glfw.PollEvents();

        // @Note(Daniel): Draw frame

        // Wait for previous frame to finish
        vk.WaitForFences(
            device     = logical_device,
            fenceCount = 1,
            pFences    = &in_flight_fences[current_frame_index],
            waitAll    = true,
            timeout    = max(u64),
        )

        // Acquire next swapchain image
        current_swapchain_image_index : u32
        if res := vk.AcquireNextImageKHR(
            device      = logical_device,
            swapchain   = swapchain.handle,
            timeout     = max(u64),
            semaphore   = swapchain_image_available_sems[current_frame_index],
            fence       = /*vk.NULL_HANDLE*/{},
            pImageIndex = &current_swapchain_image_index,
        ); res == .ERROR_OUT_OF_DATE_KHR {
            log.info("Recreating swapchain!")
            log.debugf("    Acquire next image result: {}", res)
            swapchain_delete(logical_device, swapchain)
            swapchain = swapchain_make(window, window_surface, surface_format, physical_device, logical_device, render_pass)
            continue
        }
        else if res != .SUCCESS && res != .SUBOPTIMAL_KHR {
            log.panicf("Failed to acquire next swapchain image! Error: {}", res)
        }

        vk.ResetFences(logical_device, 1, &in_flight_fences[current_frame_index])

        // Reset and record commmand buffer
        vk.ResetCommandBuffer(command_buffers[current_frame_index], {})
        {
            // Begin recording
            command_buffer_begin_info := vk.CommandBufferBeginInfo {
                sType            = .COMMAND_BUFFER_BEGIN_INFO,
                flags            = {},
                pInheritanceInfo = nil,
            }
            if res := vk.BeginCommandBuffer(command_buffers[current_frame_index], &command_buffer_begin_info); res != .SUCCESS {
                log.panicf("Failed to begin recording command buffer! Error: {}", res)
            }
            defer if res := vk.EndCommandBuffer(command_buffers[current_frame_index]); res != .SUCCESS {
                log.panicf("Failed to end recording command buffer! Error: {}", res)
            }

            // Begin render pass
            clear_color := vk.ClearValue { color = { float32 = { 0.0, 0.0, 0.0, 1.0 } } }
            render_pass_begin_info := vk.RenderPassBeginInfo {
                sType           = .RENDER_PASS_BEGIN_INFO,
                renderPass      = render_pass,
                clearValueCount = 1,
                pClearValues    = &clear_color,
                framebuffer     = swapchain.framebuffers[current_swapchain_image_index],
                renderArea      = {
                    offset = { 0, 0 },
                    extent = swapchain.extents,
                },
            }
            vk.CmdBeginRenderPass(command_buffers[current_frame_index], &render_pass_begin_info, .INLINE)
            defer vk.CmdEndRenderPass(command_buffers[current_frame_index])

            // Bind the graphics pipeline
            vk.CmdBindPipeline(command_buffers[current_frame_index], .GRAPHICS, graphics_pipeline)

            // Set viewport
            viewport := vk.Viewport {
                x        = 0.0,
                y        = 0.0,
                width    = cast(f32) swapchain.extents.width,
                height   = cast(f32) swapchain.extents.height,
                minDepth = 0.0,
                maxDepth = 1.0,
            }
            vk.CmdSetViewport(command_buffers[current_frame_index], 0, 1, &viewport)

            // Set scissor
            scissor := vk.Rect2D {
                offset = { 0, 0 },
                extent = swapchain.extents,
            }
            vk.CmdSetScissor(command_buffers[current_frame_index], 0, 1, &scissor)

            // Bind vertex buffer
            offsets := [?]vk.DeviceSize{ 0 }
            vk.CmdBindVertexBuffers(command_buffers[current_frame_index], 0, 1, &vertex_buffer, raw_data(&offsets))


            // Actually draw
            vk.CmdDraw(command_buffers[current_frame_index], len(vertices), 1, 0, 0)
        }

        // Submit command buffer to graphics queue
        submit_info := vk.SubmitInfo {
            sType                = .SUBMIT_INFO,
            commandBufferCount   = 1,
            pCommandBuffers      = &command_buffers[current_frame_index],
            waitSemaphoreCount   = 1,
            pWaitSemaphores      = &swapchain_image_available_sems[current_frame_index],
            signalSemaphoreCount = 1,
            pSignalSemaphores    = &render_finished_sems[current_frame_index],
            pWaitDstStageMask    = &vk.PipelineStageFlags{ .COLOR_ATTACHMENT_OUTPUT },
        }
        if res := vk.QueueSubmit(graphics_queue, 1, &submit_info, in_flight_fences[current_frame_index]); res != .SUCCESS {
            log.panicf("Failed to submit command buffer to graphics queue! Error: {}", res)
        }

        // Present the queue to the swapchain
        present_info := vk.PresentInfoKHR {
            sType              = .PRESENT_INFO_KHR,
            waitSemaphoreCount = 1,
            pWaitSemaphores    = &render_finished_sems[current_frame_index],
            swapchainCount     = 1,
            pSwapchains        = &swapchain.handle,
            pImageIndices      = &current_swapchain_image_index,
        }

        if res := vk.QueuePresentKHR(presentation_queue, &present_info); res == .ERROR_OUT_OF_DATE_KHR || res == .SUBOPTIMAL_KHR || framebuffer_resized {
            log.info("Recreating swapchain!")
            log.debugf("    Queue present result: {} | Framebuffer resized = {}", res, framebuffer_resized)
            swapchain_delete(logical_device, swapchain)
            swapchain = swapchain_make(window, window_surface, surface_format, physical_device, logical_device, render_pass)
            framebuffer_resized = false
        }
        else if res != .SUCCESS {
            log.panicf("Failed to present queue! Error: {}", res)
        }

        current_frame_index = (current_frame_index + 1) % MAX_FRAMES_IN_FLIGHT
    }

    // @Note(Daniel): Let the device finish before cleaning up resources
    vk.DeviceWaitIdle(logical_device)
}

debug_messenger_create_info_create :: proc() -> vk.DebugUtilsMessengerCreateInfoEXT {

    debug_callback :: proc "system" (
        message_severity   : vk.DebugUtilsMessageSeverityFlagsEXT,
        message_type_flags : vk.DebugUtilsMessageTypeFlagsEXT,
        callback_data      : ^vk.DebugUtilsMessengerCallbackDataEXT,
        user_data          : rawptr,
    ) -> b32 {
        context = setup_context()
        switch {
            case callback_data.messageIdNumber == 0xde3cbaf:       fallthrough
            case callback_data.pMessageIdName == "Loader Message":
                return false
        }

        type_str_buf := strings.builder_make()
        defer strings.builder_destroy(&type_str_buf)
        for dumtf in vk.DebugUtilsMessageTypeFlagEXT {
            if dumtf in message_type_flags {
                fmt.sbprintf(&type_str_buf, "{}/", dumtf)
            }
        }
        unordered_remove(&type_str_buf.buf, len(type_str_buf.buf) - 1)
        type_str := strings.to_string(type_str_buf)

        format_str := fmt.tprintf("{}{{}} (0x{:x}: {}):\n{}", type_str, transmute(u32) callback_data.messageIdNumber, callback_data.pMessageIdName, callback_data.pMessage)
        switch {
            case message_severity >= { .ERROR }:   log.errorf(format_str, " Error")
            case message_severity >= { .WARNING }: log.warnf(format_str, " Warning")
            case:                                  log.logf(log.Level(100), format_str, "")
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


Queue_Family_Indices :: struct {
    graphics,
    presentation : Maybe(u32),
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

Swapchain_Available_Support :: struct {
    capabilities    : vk.SurfaceCapabilitiesKHR,
    surface_formats : []vk.SurfaceFormatKHR,
    present_modes   : []vk.PresentModeKHR,
}
swapchain_available_support_make :: proc(physical_device : vk.PhysicalDevice, surface : vk.SurfaceKHR, allocator := context.allocator, loc := #caller_location) -> (swapchain_available : Swapchain_Available_Support) {
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &swapchain_available.capabilities)

    available_surface_format_count : u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &available_surface_format_count, nil)
    swapchain_available.surface_formats = make([]vk.SurfaceFormatKHR, available_surface_format_count, allocator, loc)
    vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &available_surface_format_count, raw_data(swapchain_available.surface_formats))

    available_present_mode_count : u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &available_present_mode_count, nil)
    swapchain_available.present_modes = make([]vk.PresentModeKHR, available_present_mode_count, allocator, loc)

    vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &available_present_mode_count, raw_data(swapchain_available.present_modes))

    return
}
swapchain_available_support_delete :: proc(using swapchain_available : Swapchain_Available_Support, allocator := context.allocator, loc := #caller_location) {
    delete(surface_formats, allocator, loc)
    delete(present_modes, allocator, loc)
}

Swapchain :: struct {
    handle         : vk.SwapchainKHR,
    surface_format : vk.SurfaceFormatKHR,
    extents        : vk.Extent2D,
    images         : []vk.Image,
    image_views    : []vk.ImageView,
    framebuffers   : []vk.Framebuffer,
}
swapchain_make :: proc(
    window          : glfw.WindowHandle,
    window_surface  : vk.SurfaceKHR,
    surface_format  : vk.SurfaceFormatKHR,
    physical_device : vk.PhysicalDevice,
    logical_device  : vk.Device,
    render_pass     : vk.RenderPass,
    allocator       := context.allocator,
) -> (swapchain : Swapchain) {
    width, height := glfw.GetFramebufferSize(window)
    for width == 0 || height == 0 {
        width, height = glfw.GetFramebufferSize(window)
        glfw.WaitEvents()
    }

    vk.DeviceWaitIdle(logical_device)
    swapchain.surface_format = surface_format

    // @Note(Daniel): Query swapchain capabilities
    swapchain_available := swapchain_available_support_make(physical_device, window_surface, allocator)
    defer swapchain_available_support_delete(swapchain_available)

    // @Note(Daniel): Choose present mode
    swapchain_present_mode : vk.PresentModeKHR
    for mode in swapchain_available.present_modes {
        if mode == .MAILBOX {
            swapchain_present_mode = mode
            break
        }
        swapchain_present_mode = .FIFO
    }

    // @Note(Daniel): Choose swap extents
    if swapchain_available.capabilities.currentExtent.width != max(u32) {
        swapchain.extents = swapchain_available.capabilities.currentExtent
    }
    else {
        using swapchain_available.capabilities
        width, height := glfw.GetFramebufferSize(window)
        swapchain.extents = {
            width  = clamp(cast(u32) width,  minImageExtent.width,  maxImageExtent.width),
            height = clamp(cast(u32) height, minImageExtent.height, maxImageExtent.height),
        }
    }

    // @Note(Daniel): Create swapchain
    swapchain_min_image_count := swapchain_available.capabilities.minImageCount + 1
    if swapchain_available.capabilities.maxImageCount > 0 && swapchain_min_image_count > swapchain_available.capabilities.maxImageCount {
        swapchain_min_image_count = swapchain_available.capabilities.maxImageCount
    }

    queue_family_indices := find_queue_families(physical_device, window_surface)
    shared_queue_family_indices := (queue_family_indices.graphics.? == queue_family_indices.presentation.?)
    indices := [?]u32 {
        queue_family_indices.graphics.?,
        queue_family_indices.presentation.?,
    }

    swapchain_create_info := vk.SwapchainCreateInfoKHR {
        sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
        surface               = window_surface,
        imageFormat           = swapchain.surface_format.format,
        imageColorSpace       = swapchain.surface_format.colorSpace,
        presentMode           = swapchain_present_mode,
        imageExtent           = swapchain.extents,
        minImageCount         = swapchain_min_image_count,

        imageArrayLayers      = 1,
        preTransform          = swapchain_available.capabilities.currentTransform,
        imageUsage            = { .COLOR_ATTACHMENT },
        compositeAlpha        = { .OPAQUE },
        clipped               = true,
        oldSwapchain          = vk.SwapchainKHR(0),

        imageSharingMode      =  .CONCURRENT            if !shared_queue_family_indices else .EXCLUSIVE,
        queueFamilyIndexCount =  auto_cast len(indices) if !shared_queue_family_indices else 0,
        pQueueFamilyIndices   =  raw_data(&indices)     if !shared_queue_family_indices else nil,
    }

    if res := vk.CreateSwapchainKHR(logical_device, &swapchain_create_info, nil, &swapchain.handle); res != .SUCCESS {
        log.panicf("Failed to create swapchain! Error: {}", res)
    }
    log.debugf("Created swapchain ({}x{})", swapchain.extents.width, swapchain.extents.height)
    log.debugf("    -- Image format: {}", swapchain.surface_format.format)
    log.debugf("    -- Present mode: {}", swapchain_present_mode)

    // @Note(Daniel): Get swapchain images
    swapchain_image_count : u32
    vk.GetSwapchainImagesKHR(logical_device, swapchain.handle, &swapchain_image_count, nil)

    swapchain.images      = make([]vk.Image,     swapchain_image_count, allocator)
    swapchain.image_views = make([]vk.ImageView, swapchain_image_count, allocator)

    vk.GetSwapchainImagesKHR(logical_device, swapchain.handle, &swapchain_image_count, raw_data(swapchain.images))

    // @Note(Daniel): Create image views for swapchain images
    for image, i in swapchain.images {
        view_create_info := vk.ImageViewCreateInfo {
            sType            = .IMAGE_VIEW_CREATE_INFO,
            image            = image,
            viewType         = .D2,
            format           = swapchain.surface_format.format,
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

        if res := vk.CreateImageView(logical_device, &view_create_info, nil, &swapchain.image_views[i]); res != .SUCCESS {
            log.panicf("Failed to create image view #{}! Error: {}", i, res)
        }
    }
    log.debugf("Created {} swapchain image(s) and image view(s)", swapchain_image_count)

    // @Note(Daniel): Create swapchain framebuffers
    swapchain.framebuffers = make([]vk.Framebuffer, len(swapchain.image_views), allocator)
    for framebuffer, i in &swapchain.framebuffers {
        framebuffer_create_info := vk.FramebufferCreateInfo {
            sType           = .FRAMEBUFFER_CREATE_INFO,
            renderPass      = render_pass,
            attachmentCount = 1,
            pAttachments    = &swapchain.image_views[i],
            width           = swapchain.extents.width,
            height          = swapchain.extents.height,
            layers          = 1,
        }

        if res := vk.CreateFramebuffer(logical_device, &framebuffer_create_info, nil, &framebuffer); res != .SUCCESS {
            log.panicf("Failed to create framebuffer #{}! Error: {}", i, res)
        }
        log.debugf("Created framebuffer #{} ({}x{}, {} attachment(s))", i, framebuffer_create_info.width, framebuffer_create_info.height, framebuffer_create_info.attachmentCount)
    }
    log.debugf("Created {} swapchain framebuffer(s)", len(swapchain.framebuffers))

    return
}
swapchain_delete :: proc(logical_device : vk.Device, swapchain : Swapchain, allocator := context.allocator, loc := #caller_location) {
    vk.DeviceWaitIdle(logical_device)

    for framebuffer in swapchain.framebuffers {
        vk.DestroyFramebuffer(logical_device, framebuffer, nil)
    }
    delete(swapchain.framebuffers, allocator, loc)

    for view in swapchain.image_views {
        vk.DestroyImageView(logical_device, view, nil)
    }
    delete(swapchain.image_views, allocator, loc)
    delete(swapchain.images, allocator, loc)
    vk.DestroySwapchainKHR(logical_device, swapchain.handle, nil)
}

Vertex :: struct {
    position : linalg.Vector2f32,
    color    : linalg.Vector3f32,
}

setup_context :: proc "c" () -> (ctx : runtime.Context) {
    console_logger_proc :: proc(data : rawptr, level : log.Level, text : string, options : log.Options, location := #caller_location) {
        // @Note(Daniel): Not using data parameter

        when ODIN_OS == .Windows {
            WHITE  :: win32.FOREGROUND_RED | win32.FOREGROUND_GREEN | win32.FOREGROUND_BLUE
            CYAN   ::                        win32.FOREGROUND_GREEN | win32.FOREGROUND_BLUE
            GREEN  ::                        win32.FOREGROUND_GREEN                         | win32.FOREGROUND_INTENSITY
            YELLOW :: win32.FOREGROUND_RED | win32.FOREGROUND_GREEN                         | win32.FOREGROUND_INTENSITY
            RED    :: win32.FOREGROUND_RED                                                  | win32.FOREGROUND_INTENSITY
        }
        else {
            WHITE  :: "\x1b[0m"
            CYAN   :: "\x1b[36m"
            GREEN  :: "\x1b[92m"
            YELLOW :: "\x1b[93m"
            RED    :: "\x1b[91m"
        }

        color := WHITE
        if options >= { .Level, .Terminal_Color } {
            switch level {
                case .Debug:         color = CYAN
                case .Info:          color = GREEN
                case .Warning:       color = YELLOW
                case .Error, .Fatal: color = RED
            }
        }

        log_level, ok := fmt.enum_value_to_string(level)
        if !ok { log_level = "Trace" }

        when ODIN_OS == .Windows {
            format_str := fmt.tprintf("[{: 7s}] [{{: 25s}}] {}\n", log_level, text)
        }
        else {
            format_str := fmt.tprintf("{}[{: 7s}] [{{: 25s}}] {}{}\n", color, log_level, text, WHITE)
        }
        loc_str := fmt.tprintf("{}:{}:{}", location.file_path if level == .Fatal else location.procedure, location.line, location.column)

        when ODIN_OS == .Windows { win32.SetConsoleTextAttribute(win32.GetStdHandle(win32.STD_OUTPUT_HANDLE), color) }
        fmt.printf(format_str, loc_str)
        when ODIN_OS == .Windows { win32.SetConsoleTextAttribute(win32.GetStdHandle(win32.STD_OUTPUT_HANDLE), WHITE) }

        if level == .Fatal {
            when ODIN_DEBUG { intrinsics.debug_trap() }
            else { os.exit(1) }
        }
    }

    ctx = runtime.default_context()
    ctx.logger = log.Logger {
        data         = nil,
        procedure    = console_logger_proc,
        options      = { .Level, .Terminal_Color },
        lowest_level = .Debug when ODIN_DEBUG else .Warning,
    }

    return
}
