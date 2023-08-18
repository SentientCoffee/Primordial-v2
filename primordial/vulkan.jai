#add_context vk : struct {
    module      : Win32.HMODULE;
    instance    : Instance;
    surface     : Surface;
    device      : Device;
    swapchain   : Swapchain;
    render_pass : Render_Pass;
}

// -------------------------------------------------------

Instance :: struct {
    #as handle : Vk.Instance;

    extensions :: *u8.[
        Vk.KHR_SURFACE_\     EXTENSION_NAME,
        Vk.KHR_WIN32_SURFACE_EXTENSION_NAME,
        Vk.EXT_DEBUG_UTILS_\ EXTENSION_NAME,
    ];
    layers :: *u8.[
        Vk.KHR_VALIDATION_LAYER_NAME,
    ];
}

Surface :: struct {
    #as handle : Vk.SurfaceKHR;
    format     : Vk.SurfaceFormatKHR;
}

// -------------------------------------------------------

Queue_Family_Index_Type :: enum {
    Graphics;
    Transfer;
    Present;
}

Device :: struct {
    #as handle           : Vk.Device;
    physical_device      : Vk.PhysicalDevice;
    properties           : Vk.PhysicalDeviceProperties;
    queue_family_indices : Enum_Array(Queue_Family_Index_Type, u32);
    depth_format         : Vk.Format;

    extensions :: *u8.[
        Vk.KHR_SWAPCHAIN_EXTENSION_NAME,
    ];
}

get_physical_device_info :: () {
    physical_device := context.vk.device.physical_device;

    context.vk.device.properties = Vk.get_physical_device_properties(physical_device);

    device_extensions, _ := Vk.enumerate_device_extension_properties(physical_device, null);
    defer array_free(device_extensions);

    device_props := context.vk.device.properties;
    device_name := to_string(device_props.deviceName.data);

    log_info("Physical device: % (0x%)", device_name, FormatInt.{value = device_props.deviceID, base = 16});

    builder := string_builder_make();

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

        if is_req then string_builder_print(*builder, "\x1b[32m%\x1b[0m", avail_ext_name);
        else           string_builder_print(*builder, "%", avail_ext_name);

        if it_index < device_extensions.count-1 then string_builder_append(*builder, ", ");
    }

    log_trace("Device extensions: %", builder_to_string(*builder));
}

// -------------------------------------------------------

Render_Pass :: struct {
    #as handle  : Vk.RenderPass;
    attachments : []Vk.AttachmentDescription;
}

render_pass_make :: (device : Device, surface : Surface) -> Render_Pass {
    render_pass : Render_Pass;

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
    ];

    rp_color_attachment_refs := Vk.AttachmentReference.[
        .{ attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL },
    ];

    rp_subpasses := Vk.SubpassDescription.[
        .{
            pipelineBindPoint    = .GRAPHICS,
            colorAttachmentCount = rp_color_attachment_refs.count,
            pColorAttachments    = rp_color_attachment_refs.data,
        },
    ];
    rp_subpass_dependencies := Vk.SubpassDependency.[
        .{
            srcSubpass    = Vk.SUBPASS_EXTERNAL,
            dstSubpass    = 0,
            srcStageMask  = .COLOR_ATTACHMENT_OUTPUT,
            dstStageMask  = .COLOR_ATTACHMENT_OUTPUT,
            srcAccessMask = 0,
            dstAccessMask = .COLOR_ATTACHMENT_WRITE,
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
    return render_pass;
}

render_pass_destroy :: (device : Device, render_pass : Render_Pass) {
    Vk.DestroyRenderPass(device.handle, render_pass.handle, null);
}

// -------------------------------------------------------

Buffer_With_Memory :: struct {
    buffer : Vk.Buffer;
    memory : Vk.DeviceMemory;
}

buffer_with_memory_make :: (buffer_size : Vk.DeviceSize, buffer_usage : Vk.BufferUsageFlags, memory_property_flags : Vk.MemoryPropertyFlags) -> Buffer_With_Memory, Vk.Result {
    device := context.vk.device.handle;
    buffer : Buffer_With_Memory;
    result : Vk.Result;

    buffer.buffer, result = Vk.create_buffer(device, *Vk.BufferCreateInfo.{ size = buffer_size, usage = buffer_usage, sharingMode = .EXCLUSIVE });
    defer if result != .SUCCESS then Vk.DestroyBuffer(device, buffer.buffer, null);

    buffer_mem_reqs   := Vk.get_buffer_memory_requirements(device, buffer.buffer);
    memory_type_index := get_memory_type_index(memory_property_flags, buffer_mem_reqs.memoryTypeBits);

    buffer.memory, result = Vk.allocate_memory(device, *Vk.MemoryAllocateInfo.{ allocationSize  = buffer_mem_reqs.size, memoryTypeIndex = memory_type_index });
    defer if result != .SUCCESS then Vk.FreeMemory(device, buffer.memory, null);

    result = Vk.BindBufferMemory(device, buffer.buffer, buffer.memory, memoryOffset = 0);
    // assert(false, "CHANGE THIS BACK!!!! Should be result != .SUCCESS!! This is just to step through.");
    if result != .SUCCESS then return .{null, null}, result;

    return buffer, result;
}

buffer_with_memory_destroy :: (buffer : Buffer_With_Memory) {
    Vk.FreeMemory(context.vk.device.handle, buffer.memory, null);
    Vk.DestroyBuffer(context.vk.device.handle, buffer.buffer, null);
}

get_memory_type_index :: (memory_property_flags : Vk.MemoryPropertyFlags, memory_type_bits : u32) -> u32 {
    physical_device   := context.vk.device.physical_device;
    memory_properties := Vk.get_physical_device_memory_properties(physical_device);

    memory_types := array_view(memory_properties.memoryTypes, 0, memory_properties.memoryTypeCount);
    memory_type_index : u32;
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

// -------------------------------------------------------

Swapchain :: struct {
    #as handle   : Vk.SwapchainKHR;
    using extent : Vk.Extent2D;
    present_mode : Vk.PresentModeKHR;
    images       : []Vk.Image;
    image_views  : []Vk.ImageView;
    framebuffers : []Vk.Framebuffer;
}

swapchain_make :: (device : Device, surface : Surface, width : u32, height : u32) -> Swapchain {
    swapchain : Swapchain;

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


    swapchain.extent = Vk.Extent2D.{ width, height };
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

    gfx_family_index     := device.queue_family_indices[Queue_Family_Index_Type.Graphics];
    present_family_index := device.queue_family_indices[Queue_Family_Index_Type.Present];
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

    swapchain_images, _    := Vk.get_swapchain_images(device.handle, swapchain.handle);
    swapchain.image_views  = NewArray(swapchain_images.count, Vk.ImageView);
    for swapchain_images {
        view_ci := Vk.ImageViewCreateInfo.{
            image            = it,
            viewType         = ._2D,
            format           = surface.format.format,
            components       = .{
                r = .IDENTITY,
                g = .IDENTITY,
                b = .IDENTITY,
                a = .IDENTITY,
            },
            subresourceRange = .{
                aspectMask     = .COLOR,
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1,
            },
        };

        swapchain.image_views[it_index], _ = Vk.create_image_view(device.handle, *view_ci);
    }

    // @Todo: create depth image
    // depth_format_candidates := Vk.Format.[.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT];
    // for depth_format_candidates {
    //     format_properties := Vk.get_physical_device_format_properties(device.physical_device, it);
    //     if format_properties.optimalTilingFeatures & .DEPTH_STENCIL_ATTACHMENT == .DEPTH_STENCIL_ATTACHMENT {
    //         device.depth_format = it;
    //         break;
    //     }
    //     else if format_properties.linearTilingFeatures & .DEPTH_STENCIL_ATTACHMENT == .DEPTH_STENCIL_ATTACHMENT {
    //         device.depth_format = it;
    //         break;
    //     }
    // }

    return swapchain;
}

swapchain_destroy :: (swapchain : Swapchain, device : Device) {
    Vk.DeviceWaitIdle(device.handle);

    for swapchain.image_views   Vk.DestroyImageView(device.handle, it, null);
    array_free(swapchain.image_views);

    for swapchain.framebuffers  Vk.DestroyFramebuffer(device.handle, it, null);
    array_free(swapchain.framebuffers);

    // @Todo: delete depth image

    Vk.DestroySwapchainKHR(device.handle, swapchain.handle, null);
}


generate_swapchain_framebuffers :: (swapchain : *Swapchain, device : Device, render_pass : Render_Pass) {
    swapchain.framebuffers = NewArray(swapchain.image_views.count, Vk.Framebuffer);

    for swapchain.image_views {
        framebuffer_ci := Vk.FramebufferCreateInfo.{
            renderPass      = render_pass.handle,
            attachmentCount = cast(u32) render_pass.attachments.count,
            pAttachments    = *it,
            width           = swapchain.width,
            height          = swapchain.height,
            layers          = 1,
        };

        swapchain.framebuffers[it_index], _ = Vk.create_framebuffer(device.handle, *framebuffer_ci);
    }
}

recreate_swapchain :: (swapchain : *Swapchain, device : Device, surface : Surface, render_pass : Render_Pass, width : u32, height : u32) {
    log_debug("Recreating swapchain: %x%", width, height);
    swapchain_destroy(swapchain, device);
    swapchain.* = swapchain_make(device, surface, width, height);
    generate_swapchain_framebuffers(swapchain, device, render_pass);
}
