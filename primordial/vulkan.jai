#add_context vk: struct {
    module:      *void;
    instance:    Instance;
    surface:     Surface;
    device:      Device;
    swapchain:   Swapchain;
    render_pass: Render_Pass;
}

// -------------------------------------------------------

Instance :: struct {
    handle: Vk.Instance;
    debug_messenger: Vk.DebugUtilsMessengerEXT;

    #if OS == .WINDOWS {
        extensions :: *u8.[
            Vk.KHR_SURFACE_\     EXTENSION_NAME,
            Vk.KHR_WIN32_SURFACE_EXTENSION_NAME,
            Vk.EXT_DEBUG_UTILS_\ EXTENSION_NAME,
        ];
    }
    else #if OS == .LINUX {
        extensions :: *u8.[
            Vk.KHR_SURFACE_\    EXTENSION_NAME,
            Vk.KHR_XLIB_SURFACE_EXTENSION_NAME,
            Vk.EXT_DEBUG_UTILS_\EXTENSION_NAME,
        ];
    }

    layers :: *u8.[
        Vk.KHR_VALIDATION_LAYER_NAME,
    ];
}

instance_make :: () {

    // -------------------------------------------------------
    // @Note: Check that we have all required extensions

    available_instance_extensions, _ := Vk.enumerate_instance_extension_properties(null);
    defer array_free(available_instance_extensions);

    for req_ext : context.vk.instance.extensions {
        req_ext_name := to_string(req_ext);

        ext_found := false;
        for available_ext : available_instance_extensions {
            avail_ext_name := to_string(available_ext.extensionName.data);

            if req_ext_name == avail_ext_name {
                ext_found = true;
                break;
            }
        }

        assert(ext_found, "Required instance extension \"%\" not found!", req_ext_name);
    }

    builder := builder_make();

    for available_ext : available_instance_extensions {
        avail_ext_name := to_string(available_ext.extensionName.data);

        is_req := false;
        for req_ext : context.vk.instance.extensions {
            req_ext_name := to_string(req_ext);
            if req_ext_name == avail_ext_name {
                is_req = true;
                break;
            }
        }

        if is_req then builder_print(*builder, "\x1b[32m%\x1b[0m", avail_ext_name);
        else           builder_print(*builder, "%", avail_ext_name);

        if it_index < available_instance_extensions.count-1 then builder_append(*builder, ", ");
    }

    log_trace("Instance extensions: %", builder_to_string(*builder));

    // -------------------------------------------------------
    // @Note: Check that we have all required layers (if any)

    available_instance_layers, _ := Vk.enumerate_instance_layer_properties();
    defer array_free(available_instance_layers);

    for req_layer : context.vk.instance.layers {
        req_layer_name := to_string(req_layer);

        layer_found := false;
        for available_layer : available_instance_layers {
            avail_layer_name := to_string(available_layer.layerName.data);

            if req_layer_name == avail_layer_name {
                layer_found = true;
                break;
            }
        }

        assert(layer_found, "Required instance layer % not found!", req_layer_name);
    }

    for available_layer : available_instance_layers {
        avail_layer_name := to_string(available_layer.layerName.data);

        is_req := false;
        for req_layer : context.vk.instance.layers {
            req_layer_name := to_string(req_layer);
            if req_layer_name == avail_layer_name {
                is_req = true;
                break;
            }
        }

        if is_req then builder_print(*builder, "\x1b[32m%\x1b[0m", avail_layer_name);
        else           builder_print(*builder, "%", avail_layer_name);

        if it_index < available_instance_layers.count-1 then builder_append(*builder, ", ");
    }

    log_trace("Instance layers: %", builder_to_string(*builder));

    // -------------------------------------------------------
    // @Note: Create vulkan instance with debug messenger

    debug_messenger_ci := Vk.DebugUtilsMessengerCreateInfoEXT.{
        messageSeverity = .VERBOSE_EXT | .INFO_EXT | .WARNING_EXT | .ERROR_EXT,
        messageType     = .GENERAL_EXT | .VALIDATION_EXT | .PERFORMANCE_EXT,
        pfnUserCallback = vk_debug_callback,
        pUserData       = *context,
    };

    app_info := Vk.ApplicationInfo.{
        pApplicationName   = "Vulkan",
        applicationVersion = Vk.MAKE_API_VERSION(0, 0, 0, 1),
        pEngineName        = "No engine",
        engineVersion      = Vk.MAKE_API_VERSION(0, 0, 0, 1),
        apiVersion         = Vk.API_VERSION_1_3
    };

    instance_ci := Vk.InstanceCreateInfo.{
        pApplicationInfo        = *app_info,
        enabledExtensionCount   = context.vk.instance.extensions.count,
        ppEnabledExtensionNames = context.vk.instance.extensions.data,
        enabledLayerCount       = context.vk.instance.layers.count,
        ppEnabledLayerNames     = context.vk.instance.layers.data,
        pNext                   = *debug_messenger_ci,
    };

    instance, _ := Vk.create_instance(*instance_ci);
    log_trace("Create instance = %%");
    context.vk.instance.handle = instance;

    log_debug("Loading instance proc addresses...");
    Vk.load_instance_proc_addresses(context.vk.instance.handle);

    context.vk.instance.debug_messenger, _ = Vk.create_debug_utils_messenger(context.vk.instance.handle, *debug_messenger_ci);
    log_trace("Create debug utils messenger = %%");
}

instance_destroy :: () {
    Vk.destroy_debug_utils_messenger(context.vk.instance.handle, context.vk.instance.debug_messenger);
    Vk.destroy_instance(context.vk.instance.handle);
}

// -------------------------------------------------------

Surface :: struct {
    handle: Vk.SurfaceKHR;
    format: Vk.SurfaceFormatKHR;
}

surface_make :: (window: $W) -> Surface
#modify {
    return W == type_of(Window.create_window(0, 0, ""));
}{
    surface: Surface;

    #if OS == .WINDOWS {
        Win32 :: #import "Windows";
        hinstance  := Win32.GetModuleHandleW(null);  // @Todo: Add GetModuleHandleExW to Windows module
        surface_ci := Vk.Win32SurfaceCreateInfoKHR.{
            hinstance = hinstance,
            hwnd      = window,
        };

        handle, _ := Vk.create_win32_surface(context.vk.instance.handle, *surface_ci);
        log_trace("Create Win32 surface = %%");
    }
    else #if OS == .LINUX {
        X11 :: #import "X11";
        surface_ci := Vk.XlibSurfaceCreateInfoKHR.{
            dpy    = X11.x_global_display,
            window = window,
        };

        handle, _ := Vk.create_xlib_surface(context.vk.instance.handle, *surface_ci);
        log_trace("Create Xlib surface = %%");
    }

    surface.handle = handle;
    return surface;
}

surface_destroy :: inline () {
    Vk.destroy_surface(context.vk.instance.handle, context.vk.surface.handle);
}

// -------------------------------------------------------

Queue_Family_Index :: enum u32 {
    Graphics;
    Transfer;
    Present;
}

Queue :: struct {
    handle:         Vk.Queue;
    family_index := #run max_of_type(u32);
}

Device :: struct {
    handle:               Vk.Device;
    physical_device:      Vk.PhysicalDevice;
    using properties:     Vk.PhysicalDeviceProperties;
    queues:               Enum_Array(Queue_Family_Index, Queue);
    depth_format:         Vk.Format;

    extensions :: *u8.[
        Vk.KHR_SWAPCHAIN_EXTENSION_NAME,
    ];
}

device_make :: () {

    // -------------------------------------------------------
    // @Note: Get the best physical device to create a logical device from

    context.vk.device.physical_device = physical_device_get();
    assert(context.vk.device.physical_device != null, "Suitable physical device not found!\n");
    context.vk.device.properties = physical_device_get_properties(context.vk.device.physical_device);

    // -------------------------------------------------------
    // @Note: Get queue families to create

    queue_families := Vk.get_physical_device_queue_family_properties(context.vk.device.physical_device);
    defer array_free(queue_families);

    for qf : queue_families {
        set_index_if_unset_or :: (qfi: Queue_Family_Index, cond: bool) -> was_set: bool #expand {
            if context.vk.device.queues[qfi].family_index != max_of_type(u32) then return false;
            if !cond                                                          then return false;

            context.vk.device.queues[qfi].family_index = `qf_index;
            return true;
        }

        qf_index := cast(u32) it_index;

        set_index_if_unset_or(.Present, Vk.get_physical_device_surface_support(context.vk.device.physical_device, qf_index, context.vk.surface.handle));
        set_index_if_unset_or(.Graphics, (qf.queueFlags & .GRAPHICS) != 0);
        set_index_if_unset_or(.Transfer, (qf.queueFlags & .TRANSFER) != 0);

        all_indices_set := true;
        for q : context.vk.device.queues {
            if q.family_index != max_of_type(u32) then continue;

            all_indices_set = false;
            break;
        }
        if all_indices_set then break;
    }

    unique_queue_family_indices: [..]u32;
    unique_queue_family_indices.allocator = temp;
    defer array_free(unique_queue_family_indices);
    for context.vk.device.queues {
        array_add_if_unique(*unique_queue_family_indices, it.family_index);
    }

    queue_create_infos := NewArray(unique_queue_family_indices.count, Vk.DeviceQueueCreateInfo);
    defer array_free(queue_create_infos);
    for unique_queue_family_indices {
        queue_priorities := float32.[1.0];
        queue_create_infos[it_index] = Vk.DeviceQueueCreateInfo.{
            queueCount       = 1,
            queueFamilyIndex = it,
            pQueuePriorities = queue_priorities.data,
        };
    }

    // -------------------------------------------------------
    // @Note: Create logical device

    physical_device_features := Vk.PhysicalDeviceFeatures.{
        samplerAnisotropy = .TRUE,
    };

    device_ci := Vk.DeviceCreateInfo.{
        queueCreateInfoCount    = xx queue_create_infos.count,
        pQueueCreateInfos       = queue_create_infos.data,
        pEnabledFeatures        = *physical_device_features,
        enabledExtensionCount   = context.vk.device.extensions.count,
        ppEnabledExtensionNames = context.vk.device.extensions.data,

        // @Note: Not necessary anymore, but for compatibility with older Vulkan implementations we set these anyway
        enabledLayerCount       = context.vk.instance.layers.count,
        ppEnabledLayerNames     = context.vk.instance.layers.data,
    };

    context.vk.device.handle, _ = Vk.create_device(context.vk.device.physical_device, *device_ci);
    log_trace("Create device = %%");

    log_debug("Loading device proc addresses...");
    Vk.load_device_proc_addresses(context.vk.device.handle);


    for * context.vk.device.queues {
        it.handle = Vk.get_device_queue(context.vk.device.handle, it.family_index, 0);
    }
    // gfx_queue      := Vk.get_device_queue(context.vk.device.handle, get(context.vk.device.queues, .Graphics).family_index, 0);
    // transfer_queue := Vk.get_device_queue(context.vk.device.handle, get(context.vk.device.queues, .Transfer).family_index, 0);
    // present_queue  := Vk.get_device_queue(context.vk.device.handle, get(context.vk.device.queues, .Present).family_index,  0);
}

device_destroy :: () {
    Vk.destroy_device(context.vk.device.handle);
}

physical_device_get :: () -> Vk.PhysicalDevice {

    // -------------------------------------------------------
    // @Note: For now just pick the first GPU we find that has all the things we need.
    //        Later we can pick the best one, or make a UI system to pick the GPU.

    available_physical_devices, _ := Vk.enumerate_physical_devices(context.vk.instance.handle);
    assert(available_physical_devices.count > 0, "Physical device with Vulkan support not found!");
    defer array_free(available_physical_devices);

    for pd : available_physical_devices {
        props := Vk.get_physical_device_properties(pd);

        available_device_extensions, _ := Vk.enumerate_device_extension_properties(pd, null);
        defer array_free(available_device_extensions);

        for req_ext : context.vk.device.extensions {
            req_ext_name := to_string(req_ext);

            ext_found := false;
            for available_ext : available_device_extensions {
                avail_ext_name := to_string(available_ext.extensionName.data);
                if req_ext_name == avail_ext_name {
                    ext_found = true;
                    break;
                }
            }

            if !ext_found then continue pd;
        }

        queue_families := Vk.get_physical_device_queue_family_properties(pd);
        defer array_free(queue_families);

        has_graphics_support := false;
        has_transfer_support := false;
        has_present_support  := false;

        for qf, qf_index : queue_families {
            if !has_graphics_support {
                has_graphics_support = (qf.queueFlags & .GRAPHICS) != 0;
            }
            if !has_transfer_support {
                has_transfer_support = (qf.queueFlags & .TRANSFER) != 0;
            }
            if !has_present_support {
                has_present_support, _ = Vk.get_physical_device_surface_support(pd, cast(u32) qf_index, context.vk.surface.handle);
            }
        }

        surface_formats, _ := Vk.get_physical_device_surface_formats(pd, context.vk.surface.handle);
        defer array_free(surface_formats);

        present_modes, _ := Vk.get_physical_device_surface_present_modes(pd, context.vk.surface.handle);
        defer array_free(present_modes);

        features := Vk.get_physical_device_features(pd);

        log_trace(
            "% (0x%): Graphics = % | Transfer = % | Present = % | Surface formats = % | Present modes = % | Anisotropy = %",
            to_string(props.deviceName.data), FormatInt.{value = props.deviceID, base = 16},
            has_graphics_support, has_transfer_support, has_present_support, surface_formats.count, present_modes.count, features.samplerAnisotropy
        );


        if !has_graphics_support || !has_transfer_support || !has_present_support then continue pd;
        if surface_formats.count <= 0                                             then continue pd;
        if present_modes.count   <= 0                                             then continue pd;
        if features.samplerAnisotropy == .FALSE                                   then continue pd;

        return pd;
    }

    return null;
}

physical_device_get_properties :: (physical_device: Vk.PhysicalDevice) -> Vk.PhysicalDeviceProperties {
    device_props := Vk.get_physical_device_properties(physical_device);

    // @Note: Debug info logging
    device_extensions, _ := Vk.enumerate_device_extension_properties(physical_device, null);
    defer array_free(device_extensions);

    device_name := to_string(device_props.deviceName.data);

    log_info("Physical device: % (0x%)", device_name, FormatInt.{value = device_props.deviceID, base = 16});

    builder := builder_make();

    for available_ext : device_extensions {
        avail_ext_name := to_string(available_ext.extensionName.data);

        is_req := false;
        for req_ext : context.vk.device.extensions {
            req_ext_name := to_string(req_ext);
            if req_ext_name == avail_ext_name {
                is_req = true;
                break;
            }
        }

        if is_req then builder_print(*builder, "\x1b[32m%\x1b[0m", avail_ext_name);
        else           builder_print(*builder, "%", avail_ext_name);

        if it_index < device_extensions.count-1 then builder_append(*builder, ", ");
    }

    log_trace("Device extensions: %", builder_to_string(*builder));

    return device_props;
}

// -------------------------------------------------------

Buffer_With_Memory :: struct {
    buffer: Vk.Buffer;
    memory: Vk.DeviceMemory;
}

get_memory_type_index :: (memory_property_flags: Vk.MemoryPropertyFlags, memory_type_bits: u32) -> u32 {
    physical_device   := context.vk.device.physical_device;
    memory_properties := Vk.get_physical_device_memory_properties(physical_device);

    memory_types      := array_view(memory_properties.memoryTypes, 0, memory_properties.memoryTypeCount);
    memory_type_index := max_of_type(u32);
    for memory_types {
        idx := cast(u32) it_index;
        is_compatible_memory_type  := (memory_type_bits & (1 << idx)) != 0;
        supports_memory_properties := (it.propertyFlags & memory_property_flags) == memory_property_flags;
        if is_compatible_memory_type && supports_memory_properties {
            memory_type_index = idx;
            break;
        }
    }

    return memory_type_index;
}

buffer_with_memory_make :: (size: Vk.DeviceSize, usage: Vk.BufferUsageFlags, memory_property_flags: Vk.MemoryPropertyFlags) -> Buffer_With_Memory, Vk.Result {
    device := context.vk.device.handle;
    buffer: Buffer_With_Memory;
    result: Vk.Result;

    buffer_ci := Vk.BufferCreateInfo.{
        size        = size,
        usage       = usage,
        sharingMode = .EXCLUSIVE
    };

    buffer.buffer, result = Vk.create_buffer(device, *buffer_ci);
    log_trace("Create buffer = %", result);
    if result != .SUCCESS then return .{}, result;

    buffer_mem_reqs   := Vk.get_buffer_memory_requirements(device, buffer.buffer);
    memory_type_index := get_memory_type_index(memory_property_flags, buffer_mem_reqs.memoryTypeBits);

    buffer.memory, result = Vk.allocate_memory(device, *(Vk.MemoryAllocateInfo.{ allocationSize = buffer_mem_reqs.size, memoryTypeIndex = memory_type_index }));
    log_trace("Allocate memory = %", result);
    if result != .SUCCESS then return .{}, result;

    result = Vk.BindBufferMemory(device, buffer.buffer, buffer.memory, memoryOffset = 0);
    log_trace("Bind buffer memory = %", result);
    if result != .SUCCESS then return .{}, result;

    return buffer, result;
}

buffer_with_memory_destroy :: (buffer: Buffer_With_Memory) {
    Vk.free_memory(context.vk.device.handle, buffer.memory);
    Vk.destroy_buffer(context.vk.device.handle, buffer.buffer);
}

// -------------------------------------------------------

Image :: struct {
    image:   Vk.Image;
    view:    Vk.ImageView;
    memory:  Vk.DeviceMemory;

    format: Vk.Format;
}

image_make :: (width: u32, height: u32, format: Vk.Format, tiling: Vk.ImageTiling, usage: Vk.ImageUsageFlags, memory_property_flags: Vk.MemoryPropertyFlags) -> Image, Vk.Result {
    device := context.vk.device.handle;
    image:  Image;
    result: Vk.Result;

    image_ci := Vk.ImageCreateInfo.{
        imageType     = ._2D,
        extent        = .{ width = width, height = height, depth = 1 },
        mipLevels     = 1,
        arrayLayers   = 1,
        format        = format,
        tiling        = tiling,
        initialLayout = .UNDEFINED,
        usage         = usage,
        sharingMode   = .EXCLUSIVE,
        samples       = ._1,
        flags         = 0,
    };

    image.image, result = Vk.create_image(device, *image_ci);
    log_trace("Create image = %", result);
    if result != .SUCCESS then return .{}, result;

    image.format = format;

    image_mem_reqs    := Vk.get_image_memory_requirements(device, image.image);
    memory_type_index := get_memory_type_index(memory_property_flags, image_mem_reqs.memoryTypeBits);

    image.memory, result = Vk.allocate_memory(device, *(Vk.MemoryAllocateInfo.{ allocationSize = image_mem_reqs.size, memoryTypeIndex = memory_type_index }));
    log_trace("Allocate memory = %", result);
    if result != .SUCCESS then return .{}, result;

    result = Vk.BindImageMemory(device, image.image, image.memory, memoryOffset = 0);
    log_trace("Bind image memory = %", result);
    if result != .SUCCESS then return .{}, result;

    return image, result;
}

image_view_make :: (image: *Image, aspect_flags: Vk.ImageAspectFlags) -> Vk.Result {
    view_ci := Vk.ImageViewCreateInfo.{
        image            = image.image,
        viewType         = ._2D,
        format           = image.format,
        components       = .{ r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY },
        subresourceRange = .{
            aspectMask     = aspect_flags,
            baseMipLevel   = 0,
            levelCount     = 1,
            baseArrayLayer = 0,
            layerCount     = 1,
        },
    };

    view, result := Vk.create_image_view(context.vk.device.handle, *view_ci);
    log_trace("Create image view = %", result);
    if result != .SUCCESS then return result;

    image.view = view;
    return result;
}

image_destroy :: (image: Image) {
    Vk.free_memory(context.vk.device.handle, image.memory);
    Vk.destroy_image(context.vk.device.handle, image.image);
    Vk.destroy_image_view(context.vk.device.handle, image.view);
}

cmd_image_transition :: (cmdbuf: Vk.CommandBuffer, image: Image, old_layout: Vk.ImageLayout, new_layout: Vk.ImageLayout) {
    aspect_mask: Vk.ImageAspectFlags = ifx new_layout == .DEPTH_ATTACHMENT_OPTIMAL then .DEPTH else .COLOR;

    image_barrier := Vk.ImageMemoryBarrier2.{
        image           = image.image,
        srcStageMask    = .ALL_COMMANDS,
        srcAccessMask   = .MEMORY_WRITE,
        dstStageMask    = .ALL_COMMANDS,
        dstAccessMask   = .MEMORY_WRITE | .MEMORY_READ,

        oldLayout       = old_layout,
        newLayout       = new_layout,

        subresourceRange = .{
            aspectMask     = aspect_mask,
            baseMipLevel   = 0,
            levelCount     = Vk.REMAINING_MIP_LEVELS,
            baseArrayLayer = 0,
            layerCount     = Vk.REMAINING_ARRAY_LAYERS,
        },
    };

    dependency_info := Vk.DependencyInfo.{
        imageMemoryBarrierCount = 1,
        pImageMemoryBarriers    = *image_barrier,
    };

    Vk.CmdPipelineBarrier2(cmdbuf, *dependency_info);
}

// -------------------------------------------------------

Render_Pass :: struct {
    handle:      Vk.RenderPass;
    attachments: []Vk.AttachmentDescription; @Color @Depth
}

render_pass_make :: (device: Device, surface: Surface) -> Render_Pass {
    log_debug("Creating render pass...");
    log_indent_scope();

    render_pass: Render_Pass;

    render_pass.attachments = Vk.AttachmentDescription.[
        .{
            format         = surface.format.format,
            samples        = ._1,
            loadOp         = .CLEAR,
            storeOp        = .STORE,
            stencilLoadOp  = .DONT_CARE,
            stencilStoreOp = .DONT_CARE,
            initialLayout  = .UNDEFINED,
            finalLayout    = .PRESENT_SRC_KHR,
        },
        .{
            format         = device.depth_format,
            samples        = ._1,
            loadOp         = .CLEAR,
            storeOp        = .DONT_CARE,
            stencilLoadOp  = .DONT_CARE,
            stencilStoreOp = .DONT_CARE,
            initialLayout  = .UNDEFINED,
            finalLayout    = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        },
    ];

    rp_color_attachment_refs := Vk.AttachmentReference.[
        .{ attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL },
    ];
    rp_depth_attachment_ref := Vk.AttachmentReference.{
        attachment = 1, layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
    };

    rp_subpasses := Vk.SubpassDescription.[
        .{
            pipelineBindPoint       = .GRAPHICS,
            colorAttachmentCount    = rp_color_attachment_refs.count,
            pColorAttachments       = rp_color_attachment_refs.data,
            pDepthStencilAttachment = *rp_depth_attachment_ref,
        },
    ];
    rp_subpass_dependencies := Vk.SubpassDependency.[
        .{
            srcSubpass    = Vk.SUBPASS_EXTERNAL,
            dstSubpass    = 0,
            srcStageMask  = .COLOR_ATTACHMENT_OUTPUT | .EARLY_FRAGMENT_TESTS,
            dstStageMask  = .COLOR_ATTACHMENT_OUTPUT | .EARLY_FRAGMENT_TESTS,
            srcAccessMask = 0,
            dstAccessMask = .COLOR_ATTACHMENT_WRITE | .DEPTH_STENCIL_ATTACHMENT_WRITE,
        },
    ];

    render_pass_ci := Vk.RenderPassCreateInfo.{
        attachmentCount = cast(u32) render_pass.attachments.count,
        pAttachments    = render_pass.attachments.data,
        subpassCount    = rp_subpasses.count,
        pSubpasses      = rp_subpasses.data,
        dependencyCount = rp_subpass_dependencies.count,
        pDependencies   = rp_subpass_dependencies.data,
    };

    render_pass.handle, _ = Vk.create_render_pass(device.handle, *render_pass_ci);
    log_trace("Create render pass = %%");
    return render_pass;
}

render_pass_destroy :: (device: Device, render_pass: Render_Pass) {
    Vk.destroy_render_pass(device.handle, render_pass.handle);
}

// -------------------------------------------------------

Swapchain :: struct {
    handle:       Vk.SwapchainKHR;
    using extent: Vk.Extent2D;
    present_mode: Vk.PresentModeKHR;

    image_views:  []Vk.ImageView;
    framebuffers: []Vk.Framebuffer;

    depth_image: Image;
}

swapchain_make :: (width: int, height: int) {
    log_debug("Creating swapchain...");
    log_indent_scope();

    device  := *context.vk.device;
    surface := *context.vk.surface;

    swapchain: Swapchain;

    surface_capabilities := Vk.get_physical_device_surface_capabilities(device.physical_device, surface.handle);
    swapchain.present_mode = Vk.PresentModeKHR.FIFO_KHR;
    {
        pd_surface_present_modes, _ := Vk.get_physical_device_surface_present_modes(device.physical_device, surface.handle);
        defer array_free(pd_surface_present_modes);
        for pd_surface_present_modes {
            if it == .MAILBOX_KHR {
                swapchain.present_mode = it;
                break;
            }
        }
    }

    swapchain.extent = Vk.Extent2D.{ cast(u32) width, cast(u32) height };
    if surface_capabilities.currentExtent.width != max_of_type(u32) {
        swapchain.extent = surface_capabilities.currentExtent;
    }
    else {
        Clamp(*swapchain.width,  surface_capabilities.minImageExtent.width,  surface_capabilities.maxImageExtent.width);
        Clamp(*swapchain.height, surface_capabilities.minImageExtent.height, surface_capabilities.maxImageExtent.height);
    }

    swapchain_min_image_count := min(
        surface_capabilities.minImageCount + 1,
        ifx surface_capabilities.maxImageCount > 0 else max_of_type(u32)
    );

    gfx_family_index     := get(device.queues, .Graphics).family_index;
    present_family_index := get(device.queues, .Present).family_index;
    queue_family_indices := u32.[gfx_family_index, present_family_index];
    shared_queue         := (gfx_family_index == present_family_index);

    swapchain_ci := Vk.SwapchainCreateInfoKHR.{
        surface               = surface.handle,
        imageFormat           = surface.format.format,
        imageColorSpace       = surface.format.colorSpace,
        presentMode           = swapchain.present_mode,
        imageExtent           = swapchain.extent,
        minImageCount         = swapchain_min_image_count,
        imageArrayLayers      = 1,
        preTransform          = surface_capabilities.currentTransform,
        imageUsage            = .COLOR_ATTACHMENT,
        compositeAlpha        = .OPAQUE_KHR,
        clipped               = .TRUE,
        oldSwapchain          = null,

        imageSharingMode      = ifx shared_queue then .EXCLUSIVE else .CONCURRENT,
        queueFamilyIndexCount = ifx shared_queue then 0          else cast(u32) queue_family_indices.count,
        pQueueFamilyIndices   = ifx shared_queue then null       else queue_family_indices.data,
    };

    swapchain.handle, _ = Vk.create_swapchain(device.handle, *swapchain_ci);
    log_trace("Create swapchain = %%");

    log_trace("Creating depth image...");
    {
        log_indent_scope();
        swapchain.depth_image, _ = image_make(swapchain.width, swapchain.height, device.depth_format, .OPTIMAL, .DEPTH_STENCIL_ATTACHMENT, .DEVICE_LOCAL);
        image_view_make(*swapchain.depth_image, .DEPTH);
    }

    swapchain_images, _   := Vk.get_swapchain_images(device.handle, swapchain.handle);
    swapchain.image_views  = NewArray(swapchain_images.count, Vk.ImageView);
    swapchain.framebuffers = NewArray(swapchain_images.count, Vk.Framebuffer);

    log_trace("Creating image views and framebuffers (%)...", swapchain_images.count);
    for swapchain_images {
        log_trace("(%) Creating image view and framebuffer...", it_index);
        log_indent_scope();
        view_ci := Vk.ImageViewCreateInfo.{
            image            = it,
            viewType         = ._2D,
            format           = surface.format.format,
            components       = .{ r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY },
            subresourceRange = .{
                aspectMask     = .COLOR,
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1,
            },
        };

        image_view, _ := Vk.create_image_view(device.handle, *view_ci);
        log_trace("Create image view = %%");
        swapchain.image_views[it_index] = image_view;

        attachments := Vk.ImageView.[image_view, swapchain.depth_image.view];
        assert(attachments.count == context.vk.render_pass.attachments.count);

        framebuffer_ci := Vk.FramebufferCreateInfo.{
            renderPass      = context.vk.render_pass.handle,
            attachmentCount = cast(u32) attachments.count,
            pAttachments    = attachments.data,
            width           = swapchain.width,
            height          = swapchain.height,
            layers          = 1,
        };

        swapchain.framebuffers[it_index], _ = Vk.create_framebuffer(device.handle, *framebuffer_ci);
        log_trace("Create framebuffer = %%");
    }

    context.vk.swapchain = swapchain;
}

swapchain_destroy :: () {
    Vk.DeviceWaitIdle(context.vk.device.handle);

    for context.vk.swapchain.image_views   Vk.destroy_image_view(context.vk.device.handle, it);
    array_free(context.vk.swapchain.image_views);

    for context.vk.swapchain.framebuffers  Vk.destroy_framebuffer(context.vk.device.handle, it);
    array_free(context.vk.swapchain.framebuffers);

    image_destroy(context.vk.swapchain.depth_image);

    Vk.destroy_swapchain(context.vk.device.handle, context.vk.swapchain.handle);
}

recreate_swapchain :: (width: int, height: int) {
    log_info("Recreating swapchain: %x%", width, height);
    swapchain_destroy();
    swapchain_make(width, height);
}

// -------------------------------------------------------

Frame_Sync :: struct {
    swapchain_image_sem: Vk.Semaphore;
    render_finished_sem: Vk.Semaphore;
    in_flight_fence:     Vk.Fence;
}

frame_sync_make :: () -> Frame_Sync, Vk.Result {
    frame_sync: Frame_Sync;

    {
        sem, result := Vk.create_semaphore(context.vk.device.handle, *(Vk.SemaphoreCreateInfo.{}));
        log_trace("Create swapchain image semaphore = %", result);
        if result != .SUCCESS then return .{}, result;
        frame_sync.swapchain_image_sem = sem;
    }
    {
        sem, result := Vk.create_semaphore(context.vk.device.handle, *(Vk.SemaphoreCreateInfo.{}));
        log_trace("Create render finished semaphore = %", result);
        if result != .SUCCESS then return .{}, result;
        frame_sync.render_finished_sem = sem;
    }
    {
        fence, result := Vk.create_fence(context.vk.device.handle, *(Vk.FenceCreateInfo.{ flags = .SIGNALED }));
        log_trace("Create in flight fence = %", result);
        if result != .SUCCESS then return .{}, result;
        frame_sync.in_flight_fence = fence;
    }

    return frame_sync, .SUCCESS;
}

frame_sync_destroy :: (using frame_sync: Frame_Sync) {
    Vk.destroy_semaphore(context.vk.device.handle, swapchain_image_sem);
    Vk.destroy_semaphore(context.vk.device.handle, render_finished_sem);
    Vk.destroy_fence(context.vk.device.handle, in_flight_fence);
}

// -------------------------------------------------------

#if OS == .WINDOWS {
    #import "Windows";
    #import "Windows_Utf8";

    load_vulkan_lib :: () -> *void {
        return LoadLibraryExW(utf8_to_wide("vulkan-1.dll",, temp), null, flags = 0);
    }

    unload_vulkan_lib :: () {
        FreeLibrary(xx context.vk.module, null, flags = 0);
    }

    vulkan_proc_loader :: (proc_name: *u8, user_data: *void) -> Vk.PFN_vkVoidFunction {
        assert(context.vk.module != null, "Must load the vk_module before loading global proc addresses!");
        return xx GetProcAddress(xx context.vk.module, proc_name);
    }
}
else #if OS == .LINUX {
    #import "POSIX";

    load_vulkan_lib :: () -> *void {
        handle := dlopen("libvulkan.so", RTLD_LAZY);
        if !handle {
            assert(false, to_string(dlerror()));
        }
        return handle;
    }

    unload_vulkan_lib :: () {
        dlclose(context.vk.module);
    }

    vulkan_proc_loader :: (proc_name: *u8, user_data: *void) -> Vk.PFN_vkVoidFunction {
        assert(context.vk.module != null, "Must load the vk_module before loading global proc addresses!");
        return dlsym(context.vk.module, proc_name);
    }
}


