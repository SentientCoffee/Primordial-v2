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
    handle : Vk.Instance;

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
    handle : Vk.SurfaceKHR;
    format     : Vk.SurfaceFormatKHR;
}

// -------------------------------------------------------

Queue_Family_Index_Type :: enum {
    Graphics;
    Transfer;
    Present;
}

Device :: struct {
    handle               : Vk.Device;
    physical_device      : Vk.PhysicalDevice;
    using properties     : Vk.PhysicalDeviceProperties;
    queue_family_indices : Enum_Array(Queue_Family_Index_Type, u32);
    depth_format         : Vk.Format;

    extensions :: *u8.[
        Vk.KHR_SWAPCHAIN_EXTENSION_NAME,
    ];
}

get_physical_device_info :: () {
    physical_device := context.vk.device.physical_device;

    context.vk.device.properties = Vk.get_physical_device_properties(physical_device);
    device_props := context.vk.device.properties;

    device_extensions, _ := Vk.enumerate_device_extension_properties(physical_device, null);
    defer array_free(device_extensions);

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

Buffer_With_Memory :: struct {
    buffer : Vk.Buffer;
    memory : Vk.DeviceMemory;
}

Image :: struct {
    image   : Vk.Image;
    view    : Vk.ImageView;
    memory  : Vk.DeviceMemory;
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

buffer_with_memory_make :: (buffer_size : Vk.DeviceSize, buffer_usage : Vk.BufferUsageFlags, memory_property_flags : Vk.MemoryPropertyFlags) -> Buffer_With_Memory, Vk.Result {
    device := context.vk.device.handle;
    buffer : Buffer_With_Memory;
    result : Vk.Result;

    buffer_ci := Vk.BufferCreateInfo.{
        size        = buffer_size,
        usage       = buffer_usage,
        sharingMode = .EXCLUSIVE
    };

    buffer.buffer, result = Vk.create_buffer(device, *buffer_ci);
    log_trace("Create buffer = %", result);
    if result != .SUCCESS then return .{}, result;

    buffer_mem_reqs   := Vk.get_buffer_memory_requirements(device, buffer.buffer);
    memory_type_index := get_memory_type_index(memory_property_flags, buffer_mem_reqs.memoryTypeBits);

    buffer.memory, result = Vk.allocate_memory(device, *Vk.MemoryAllocateInfo.{ allocationSize = buffer_mem_reqs.size, memoryTypeIndex = memory_type_index });
    log_trace("Allocate memory = %", result);
    if result != .SUCCESS then return .{}, result;

    result = Vk.BindBufferMemory(device, buffer.buffer, buffer.memory, memoryOffset = 0);
    log_trace("Bind buffer memory = %", result);
    if result != .SUCCESS then return .{}, result;

    return buffer, result;
}

buffer_with_memory_destroy :: (buffer : Buffer_With_Memory) {
    Vk.free_memory(context.vk.device.handle, buffer.memory);
    Vk.DestroyBuffer(context.vk.device.handle, buffer.buffer, null);
}

image_with_memory_make :: (image_width : u32, image_height : u32, image_format : Vk.Format, image_tiling : Vk.ImageTiling, image_usage : Vk.ImageUsageFlags, memory_property_flags : Vk.MemoryPropertyFlags) -> Image, Vk.Result {
    device := context.vk.device.handle;
    image  : Image;
    result : Vk.Result;

    image_ci := Vk.ImageCreateInfo.{
        imageType     = ._2D,
        extent        = .{ width = image_width, height = image_height, depth = 1 },
        mipLevels     = 1,
        arrayLayers   = 1,
        format        = image_format,
        tiling        = image_tiling,
        initialLayout = .UNDEFINED,
        usage         = image_usage,
        sharingMode   = .EXCLUSIVE,
        samples       = ._1,
        flags         = 0,
    };

    image.image, result = Vk.create_image(device, *image_ci);
    log_trace("Create image = %", result);
    if result != .SUCCESS then return .{}, result;

    image_mem_reqs    := Vk.get_image_memory_requirements(device, image.image);
    memory_type_index := get_memory_type_index(memory_property_flags, image_mem_reqs.memoryTypeBits);

    image.memory, result = Vk.allocate_memory(device, *Vk.MemoryAllocateInfo.{ allocationSize = image_mem_reqs.size, memoryTypeIndex = memory_type_index });
    log_trace("Allocate memory = %", result);
    if result != .SUCCESS then return .{}, result;

    result = Vk.BindImageMemory(device, image.image, image.memory, memoryOffset = 0);
    log_trace("Bind image memory = %", result);
    if result != .SUCCESS then return .{}, result;

    return image, result;
}

image_with_memory_destroy :: (image : Image) {
    Vk.free_memory(context.vk.device.handle, image.memory);
    Vk.DestroyImage(context.vk.device.handle, image.image, null);
}

// -------------------------------------------------------

Render_Pass :: struct {
    handle      : Vk.RenderPass;
    attachments : []Vk.AttachmentDescription;
}

render_pass_make :: (device : Device, surface : Surface) -> Render_Pass {
    log_debug("Creating render pass...");
    log_indent_scope();

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
    log_trace("Create render pass = %%");
    return render_pass;
}

render_pass_destroy :: (device : Device, render_pass : Render_Pass) {
    Vk.DestroyRenderPass(device.handle, render_pass.handle, null);
}

// -------------------------------------------------------

Swapchain :: struct {
    handle       : Vk.SwapchainKHR;
    using extent : Vk.Extent2D;
    present_mode : Vk.PresentModeKHR;

    image_views  : []Vk.ImageView;
    framebuffers : []Vk.Framebuffer;

    depth_image      : Image;
    depth_image_view : Vk.ImageView;
}

swapchain_make :: (width : int, height : int) {
    log_debug("Creating swapchain...");
    log_indent_scope();

    device := context.vk.device;
    surface := context.vk.surface;

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
    log_trace("Create swapchain = %%");

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

        framebuffer_ci := Vk.FramebufferCreateInfo.{
            renderPass      = context.vk.render_pass.handle,
            attachmentCount = cast(u32) context.vk.render_pass.attachments.count,
            pAttachments    = *image_view,
            width           = swapchain.width,
            height          = swapchain.height,
            layers          = 1,
        };

        swapchain.framebuffers[it_index], _ = Vk.create_framebuffer(context.vk.device.handle, *framebuffer_ci);
        log_trace("Create framebuffer = %%");
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

    context.vk.swapchain = swapchain;
}

swapchain_destroy :: () {
    Vk.DeviceWaitIdle(context.vk.device.handle);

    for context.vk.swapchain.image_views   Vk.DestroyImageView(context.vk.device.handle, it, null);
    array_free(context.vk.swapchain.image_views);

    for context.vk.swapchain.framebuffers  Vk.DestroyFramebuffer(context.vk.device.handle, it, null);
    array_free(context.vk.swapchain.framebuffers);

    // @Todo: delete depth image

    Vk.DestroySwapchainKHR(context.vk.device.handle, context.vk.swapchain.handle, null);
}

recreate_swapchain :: (width : int, height : int) {
    log_info("Recreating swapchain: %x%", width, height);
    swapchain_destroy();
    swapchain_make(width, height);
}

// -------------------------------------------------------

Frame_Sync :: struct {
    swapchain_image_sem : Vk.Semaphore;
    render_finished_sem : Vk.Semaphore;
    in_flight_fence     : Vk.Fence;
}

frame_sync_make :: () -> Frame_Sync, Vk.Result {
    frame_sync : Frame_Sync;

    {
        sem, result := Vk.create_semaphore(context.vk.device.handle, *Vk.SemaphoreCreateInfo.{});
        log_trace("Create swapchain image semaphore = %", result);
        if result != .SUCCESS then return .{}, result;
        frame_sync.swapchain_image_sem = sem;
    }
    {
        sem, result := Vk.create_semaphore(context.vk.device.handle, *Vk.SemaphoreCreateInfo.{});
        log_trace("Create render finished semaphore = %", result);
        if result != .SUCCESS then return .{}, result;
        frame_sync.render_finished_sem = sem;
    }
    {
        fence, result := Vk.create_fence(context.vk.device.handle, *Vk.FenceCreateInfo.{ flags = .SIGNALED });
        log_trace("Create in flight fence = %", result);
        if result != .SUCCESS then return .{}, result;
        frame_sync.in_flight_fence = fence;
    }

    return frame_sync, .SUCCESS;
}

frame_sync_destroy :: (using frame_sync : Frame_Sync) {
    Vk.DestroySemaphore(context.vk.device.handle, swapchain_image_sem, null);
    Vk.DestroySemaphore(context.vk.device.handle, render_finished_sem, null);
    Vk.DestroyFence(context.vk.device.handle, in_flight_fence, null);
}