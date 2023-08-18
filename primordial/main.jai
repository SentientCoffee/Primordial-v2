/* TODO:
 * - [x] Logging system
 *   - [x] Implement debug callback with logging system
 * - [x] Deal with resizes
 * - [ ] Check result values of Vk calls
 * - [ ] Test on Linux?
 *   - [ ] Generate linux vk bindings
 *   - [ ] Platform layer code
 * - [ ] Better physical device selection
 * - [ ] Better assert proc (Stop relying on Debug module)
 */

WIDTH  :: 800;
HEIGHT :: 600;
TITLE  :: "Vulkan";

MAX_FRAMES_IN_FLIGHT :: 2;

Vertex :: struct {
    position : Vector3;
    color    : Vector3;
}

VERTICES :: Vertex.[
    .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 0.8, 0.2, 0.3 } },
    .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 0.8, 0.2, 0.3 } },
    .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 0.2, 0.8, 0.3 } },
    .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 0.2, 0.8, 0.3 } },
    .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 0.2, 0.3, 0.8 } },
    .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 0.2, 0.3, 0.8 } },
    .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 0.8, 0.7, 0.3 } },
    .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 0.8, 0.7, 0.3 } },
];

VERTICES_SIZE :: size_of(type_of(VERTICES));

INDICES :: u32.[
    5, 7, 6, 6, 4, 5,
    7, 5, 3, 3, 1, 7,
    0, 1, 7, 7, 6, 0,
    1, 0, 2, 2, 3, 1,
    5, 3, 2, 2, 4, 5,
    4, 2, 0, 0, 6, 4,
];
INDICES_SIZE :: size_of(type_of(INDICES));

Matrix_Uniforms :: struct {
    model := Matrix4_Identity #align 16;
    view  := Matrix4_Identity #align 16;
    proj  := Matrix4_Identity #align 16;
}

main :: () {
    setup_context(highest_logger_level = .Debug);

    // -------------------------------------------------------
    // @Note: Create window

    app_window := Window.create_window(WIDTH, HEIGHT, TITLE);

    // -------------------------------------------------------
    // @Note: Load vulkan dll and load global commands

    context.vk.module = Win32.LoadLibraryExW(utf8_to_wide("vulkan-1.dll"), null, flags = 0);
    defer Win32.FreeLibrary(context.vk.module);

    Vk.load_global_proc_addresses((proc_name : *u8, user_data : *void) -> Vk.PFN_vkVoidFunction #c_call {
        ctx := cast(*Context) user_data;
        push_context ctx {
            assert(context.vk.module != null, "Must load the vk_module before loading global proc addresses!");
            return xx Win32.GetProcAddress(context.vk.module, proc_name);
        }
    }, *context);

    // -------------------------------------------------------
    // @Note: Check that we have all required extensions

    {
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

        builder := string_builder_make();

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

            if is_req then string_builder_print(*builder, "\x1b[32m%\x1b[0m", avail_ext_name);
            else           string_builder_print(*builder, "%", avail_ext_name);

            if it_index < available_instance_extensions.count-1 then string_builder_append(*builder, ", ");
        }

        log_trace("Instance extensions: %", builder_to_string(*builder));
    }

    // -------------------------------------------------------
    // @Note: Check that we have all required layers (if any)

    {
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

        builder := string_builder_make();

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

            if is_req then string_builder_print(*builder, "\x1b[32m%\x1b[0m", avail_layer_name);
            else           string_builder_print(*builder, "%", avail_layer_name);

            if it_index < available_instance_layers.count-1 then string_builder_append(*builder, ", ");
        }

        log_trace("Instance layers: %", builder_to_string(*builder));
    }

    // -------------------------------------------------------
    // @Note: Create vulkan instance

    debug_messenger_ci := Vk.DebugUtilsMessengerCreateInfoEXT.{
        messageSeverity = .VERBOSE_EXT | .INFO_EXT | .WARNING_EXT | .ERROR_EXT,
        messageType     = .GENERAL_EXT | .VALIDATION_EXT | .PERFORMANCE_EXT,
        pfnUserCallback = vk_debug_callback,
        pUserData       = *context,
    };

    {
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
        context.vk.instance.handle = instance;
    }

    defer Vk.DestroyInstance(context.vk.instance.handle, null);
    Vk.load_instance_proc_addresses(context.vk.instance.handle);

    debug_messenger := Vk.create_debug_utils_messenger(context.vk.instance.handle, *debug_messenger_ci);
    defer Vk.DestroyDebugUtilsMessengerEXT(context.vk.instance.handle, debug_messenger, null);

    // -------------------------------------------------------
    // @Note: Create vulkan surface

    {
        hinstance  := Win32.GetModuleHandleW(null);  // @Todo: Add GetModuleHandleExW to Windows module

        surface_ci := Vk.Win32SurfaceCreateInfoKHR.{
            hinstance = hinstance,
            hwnd      = app_window,
        };

        surface, _ := Vk.create_win32_surface(context.vk.instance.handle, *surface_ci);
        context.vk.surface.handle = surface;
    }
    defer Vk.DestroySurfaceKHR(context.vk.instance.handle, context.vk.surface.handle, null);

    // -------------------------------------------------------
    // @Note: Get the best physical device to create a logical device from

    {
        available_physical_devices, _ := Vk.enumerate_physical_devices(context.vk.instance.handle);
        defer array_free(available_physical_devices);
        assert(available_physical_devices.count > 0, "Physical device with Vulkan support not found!");

        // @Note: For now just pick the first GPU that has the required device extensions, queue families, and swapchain support.
        //        Later we can pick the best one, or make a UI system to pick the GPU.
        for pd : available_physical_devices {
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

            if !has_graphics_support || !has_transfer_support || !has_present_support then continue pd;

            surface_formats, _ := Vk.get_physical_device_surface_formats(pd, context.vk.surface.handle);
            defer array_free(surface_formats);
            if surface_formats.count <= 0 then continue pd;

            present_modes, _ := Vk.get_physical_device_surface_present_modes(pd, context.vk.surface.handle);
            defer array_free(present_modes);
            if present_modes.count <= 0 then continue pd;

            context.vk.device.physical_device = pd;
            break;
        }
        assert(context.vk.device.physical_device != null, "Physical device with required device extensions, queue families, and swapchain support not found!");
        get_physical_device_info();
    }

    {
        // -------------------------------------------------------
        // @Note: Get queue families to create

        queue_families := Vk.get_physical_device_queue_family_properties(context.vk.device.physical_device);
        defer array_free(queue_families);
        for * context.vk.device.queue_family_indices  it.* = max_of_type(u32);

        for qf : queue_families {
            qf_index := cast(u32) it_index;

            is_unset :: (qfit : Queue_Family_Index_Type) -> bool #expand {
                return context.vk.device.queue_family_indices[qfit] == max_of_type(u32);
            }

            set_index :: (qfit : Queue_Family_Index_Type) #expand {
                context.vk.device.queue_family_indices[qfit] = qf_index;
            }

            if is_unset(.Present) {
                has_present_support := Vk.get_physical_device_surface_support(context.vk.device.physical_device, qf_index, context.vk.surface.handle);
                if has_present_support then set_index(.Present);
            }

            if is_unset(.Graphics) {
                if (qf.queueFlags & .GRAPHICS) then set_index(.Graphics);
            }
            else if is_unset(.Transfer) {
                if (qf.queueFlags & .TRANSFER) then set_index(.Transfer);
            }

            all_indices_set := true;
            for q : context.vk.device.queue_family_indices {
                if q != max_of_type(u32) then continue;

                all_indices_set = false;
                break;
            }
            if all_indices_set then break;
        }

        unique_queue_family_indices : [..]u32;
        defer array_free(unique_queue_family_indices);
        for context.vk.device.queue_family_indices {
            array_add_if_unique(*unique_queue_family_indices, it);
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
        // @Note: Create logical device and get queue handles

        physical_device_features : Vk.PhysicalDeviceFeatures;
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

        device, _ := Vk.create_device(context.vk.device.physical_device, *device_ci);
        context.vk.device.handle = device;
    }

    defer Vk.DestroyDevice(context.vk.device.handle, null);
    Vk.load_device_proc_addresses(context.vk.device.handle);
    device := context.vk.device.handle;

    gfx_queue      := Vk.get_device_queue(device, context.vk.device.queue_family_indices[Queue_Family_Index_Type.Graphics], 0);
    transfer_queue := Vk.get_device_queue(device, context.vk.device.queue_family_indices[Queue_Family_Index_Type.Transfer], 0);
    present_queue  := Vk.get_device_queue(device, context.vk.device.queue_family_indices[Queue_Family_Index_Type.Present],  0);

    // -------------------------------------------------------
    // @Note: Get surface format from chosen physical device

    {
        pd_surface_formats, _ := Vk.get_physical_device_surface_formats(context.vk.device.physical_device, context.vk.surface.handle);
        defer array_free(pd_surface_formats);

        found := false;
        for pd_surface_formats {
            if it.format == .B8G8R8A8_UNORM && it.colorSpace == .SRGB_NONLINEAR_KHR {
                context.vk.surface.format = it;
                found = true;
                break;
            }
        }

        // @Note: If we can't find the preferred one then use the first available one
        if !found then context.vk.surface.format = pd_surface_formats[0];
    }

    // -------------------------------------------------------
    // @Note: Setup render pass

    context.vk.render_pass = render_pass_make(context.vk.device, context.vk.surface);
    defer render_pass_destroy(context.vk.device, context.vk.render_pass);

    // -------------------------------------------------------
    // @Note: Create shader modules

    vert_shader_path, found := table_find(*shader_table, "triangle.glsl.vert");
    assert(found, "Invalid path to vertex shader binary!");
    vert_shader_bin, success := read_entire_file(vert_shader_path);
    assert(success, "Could not read vertex shader binary!");
    defer free(vert_shader_bin);
    vert_shader_module_ci := Vk.ShaderModuleCreateInfo.{
        codeSize = cast(u64)  vert_shader_bin.count,
        pCode    = cast(*u32) vert_shader_bin.data,
    };
    vert_shader_module, _ := Vk.create_shader_module(device, *vert_shader_module_ci);
    defer Vk.DestroyShaderModule(device, vert_shader_module, null);
    vert_shader_stage_ci := Vk.PipelineShaderStageCreateInfo.{
        stage  = .VERTEX,
        module = vert_shader_module,
        pName  = "main",
    };

    frag_shader_path:, found = table_find(*shader_table, "triangle.glsl.frag");
    assert(found, "Invalid path to fragment shader binary!");
    frag_shader_bin:, success = read_entire_file(frag_shader_path);
    assert(success, "Could not read fragment shader binary!");
    defer free(frag_shader_bin);
    frag_shader_module_ci := Vk.ShaderModuleCreateInfo.{
        codeSize = cast(u64)  frag_shader_bin.count,
        pCode    = cast(*u32) frag_shader_bin.data,
    };
    frag_shader_module, _ := Vk.create_shader_module(device, *frag_shader_module_ci);
    defer Vk.DestroyShaderModule(device, frag_shader_module, null);
    frag_shader_stage_ci := Vk.PipelineShaderStageCreateInfo.{
        stage  = .FRAGMENT,
        module = frag_shader_module,
        pName  = "main",
    };

    pipeline_shader_stages := Vk.PipelineShaderStageCreateInfo.[vert_shader_stage_ci, frag_shader_stage_ci];

    // -------------------------------------------------------
    // @Note: Setup pipeline fixed function state

    dynamic_states   := Vk.DynamicState.[.VIEWPORT, .SCISSOR];
    dynamic_state_ci := Vk.PipelineDynamicStateCreateInfo.{
        dynamicStateCount = dynamic_states.count,
        pDynamicStates    = dynamic_states.data,
    };
    viewport_state_ci := Vk.PipelineViewportStateCreateInfo.{
        viewportCount = 1,
        pViewports    = null,
        scissorCount  = 1,
        pScissors     = null,
    };

    vertex_input_binding_descs := Vk.VertexInputBindingDescription.[
        .{ binding = 0, stride = size_of(Vertex), inputRate = .VERTEX },
    ];
    vertex_input_attribute_descs := Vk.VertexInputAttributeDescription.[
        .{ binding = 0, location = 0, format = .R32G32B32_SFLOAT, offset = cast(u32) offset_of(Vertex, "position") },
        .{ binding = 0, location = 1, format = .R32G32B32_SFLOAT, offset = cast(u32) offset_of(Vertex, "color") },
    ];
    vertex_input_state_ci := Vk.PipelineVertexInputStateCreateInfo.{
        vertexBindingDescriptionCount   = vertex_input_binding_descs.count,
        pVertexBindingDescriptions      = vertex_input_binding_descs.data,
        vertexAttributeDescriptionCount = vertex_input_attribute_descs.count,
        pVertexAttributeDescriptions    = vertex_input_attribute_descs.data,
    };

    input_assembly_state_ci := Vk.PipelineInputAssemblyStateCreateInfo.{
        topology = .TRIANGLE_LIST,
    };

    rasterization_state_ci := Vk.PipelineRasterizationStateCreateInfo.{
        depthClampEnable        = .FALSE,
        rasterizerDiscardEnable = .FALSE,
        polygonMode             = .FILL,
        lineWidth               = 1.0,
        cullMode                = .NONE,
        frontFace               = .COUNTER_CLOCKWISE,
        depthBiasEnable         = .FALSE,
    };

    multisample_state_ci := Vk.PipelineMultisampleStateCreateInfo.{
        sampleShadingEnable   = .FALSE,
        rasterizationSamples  = ._1,
        minSampleShading      = 1.0,
        pSampleMask           = null,
        alphaToCoverageEnable = .FALSE,
        alphaToOneEnable      = .FALSE,
    };

    attachment_color_blend_states := Vk.PipelineColorBlendAttachmentState.[
        .{
            colorWriteMask      = .R | .G | .B | .A,
            blendEnable         = .FALSE,
            srcColorBlendFactor = .ONE,
            dstColorBlendFactor = .ZERO,
            colorBlendOp        = .ADD,
            srcAlphaBlendFactor = .ONE,
            dstAlphaBlendFactor = .ZERO,
            alphaBlendOp        = .ADD,
        },
    ];
    color_blend_state_ci := Vk.PipelineColorBlendStateCreateInfo.{
        logicOpEnable   = .FALSE,
        logicOp         = .COPY,
        attachmentCount = attachment_color_blend_states.count,
        pAttachments    = attachment_color_blend_states.data,
        blendConstants  = .[0.0, 0.0, 0.0, 0.0],
    };

    depth_stencil_state_ci := Vk.PipelineDepthStencilStateCreateInfo.{
        depthTestEnable       = .FALSE,
        depthWriteEnable      = .FALSE,
        depthBoundsTestEnable = .FALSE,
        stencilTestEnable     = .FALSE,
        minDepthBounds        = 0.0,
        maxDepthBounds        = 1.0,
    };

    // -------------------------------------------------------
    // @Note: Setup descriptor set layout

    descriptor_set_layout_bindings := Vk.DescriptorSetLayoutBinding.[
        .{
            binding            = 0,
            descriptorType     = .UNIFORM_BUFFER,
            descriptorCount    = 1,
            stageFlags         = .VERTEX,
            pImmutableSamplers = null,
        }
    ];

    descriptor_set_layout_ci := Vk.DescriptorSetLayoutCreateInfo.{
        bindingCount = descriptor_set_layout_bindings.count,
        pBindings    = descriptor_set_layout_bindings.data,
    };

    descriptor_set_layout, _ := Vk.create_descriptor_set_layout(context.vk.device.handle, *descriptor_set_layout_ci);
    defer Vk.DestroyDescriptorSetLayout(device, descriptor_set_layout, null);

    // -------------------------------------------------------
    // @Note: Setup descriptor pool and descriptor sets

    descriptor_pool_sizes := Vk.DescriptorPoolSize.[
        .{
            type            = .UNIFORM_BUFFER,
            descriptorCount = MAX_FRAMES_IN_FLIGHT,
        },
    ];

    descriptor_pool_ci := Vk.DescriptorPoolCreateInfo.{
        poolSizeCount = descriptor_pool_sizes.count,
        pPoolSizes    = descriptor_pool_sizes.data,
        maxSets       = MAX_FRAMES_IN_FLIGHT,
        flags         = 0,
    };

    descriptor_pool, _ := Vk.create_descriptor_pool(context.vk.device.handle, *descriptor_pool_ci);
    defer Vk.DestroyDescriptorPool(context.vk.device.handle, descriptor_pool, null);

    set_layouts : [MAX_FRAMES_IN_FLIGHT]Vk.DescriptorSetLayout = .[descriptor_set_layout, descriptor_set_layout];

    descriptor_set_ai := Vk.DescriptorSetAllocateInfo.{
        descriptorPool     = descriptor_pool,
        descriptorSetCount = set_layouts.count,
        pSetLayouts        = set_layouts.data,
    };

    descriptor_sets, _ := Vk.allocate_descriptor_sets(context.vk.device.handle, *descriptor_set_ai);

    // -------------------------------------------------------
    // @Note: Setup pipeline layout

    pipeline_layout_ci := Vk.PipelineLayoutCreateInfo.{
        setLayoutCount         = 1,
        pSetLayouts            = *descriptor_set_layout,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = null,
    };
    pipeline_layout, _ := Vk.create_pipeline_layout(device, *pipeline_layout_ci);
    defer Vk.DestroyPipelineLayout(device, pipeline_layout, null);

    // -------------------------------------------------------
    // @Note: Setup graphics pipeline

    gfx_pipeline_ci := Vk.GraphicsPipelineCreateInfo.{
        stageCount = pipeline_shader_stages.count,
        pStages    = pipeline_shader_stages.data,

        pVertexInputState   = *vertex_input_state_ci,
        pInputAssemblyState = *input_assembly_state_ci,
        pTessellationState  = null,
        pViewportState      = *viewport_state_ci,
        pRasterizationState = *rasterization_state_ci,
        pMultisampleState   = *multisample_state_ci,
        pDepthStencilState  = *depth_stencil_state_ci,
        pColorBlendState    = *color_blend_state_ci,
        pDynamicState       = *dynamic_state_ci,

        layout     = pipeline_layout,
        renderPass = context.vk.render_pass.handle,
        subpass    = 0,
    };

    gfx_pipeline, _ := Vk.create_one_graphics_pipeline(device, *gfx_pipeline_ci);
    defer Vk.DestroyPipeline(device, gfx_pipeline, null);

    // -------------------------------------------------------
    // @Note: Setup command pools

    gfx_cmdpool_ci := Vk.CommandPoolCreateInfo.{
        flags            = .RESET_COMMAND_BUFFER,
        queueFamilyIndex = context.vk.device.queue_family_indices[Queue_Family_Index_Type.Graphics],
    };
    gfx_cmdpool, _ := Vk.create_command_pool(device, *gfx_cmdpool_ci);
    defer Vk.DestroyCommandPool(device, gfx_cmdpool, null);

    transfer_cmdpool_ci := Vk.CommandPoolCreateInfo.{
        flags            = .RESET_COMMAND_BUFFER,
        queueFamilyIndex = context.vk.device.queue_family_indices[Queue_Family_Index_Type.Transfer],
    };
    transfer_cmdpool, _ := Vk.create_command_pool(device, *transfer_cmdpool_ci);
    defer Vk.DestroyCommandPool(device, transfer_cmdpool, null);

    // -------------------------------------------------------
    // @Note: Setup transfer command buffer for mapping data to the GPU before the first frame

    transfer_cmdbuf_ai := Vk.CommandBufferAllocateInfo.{
        commandPool = transfer_cmdpool,
        level       = .PRIMARY,
    };
    transfer_cmdbuf, _ := Vk.allocate_one_command_buffer(device, *transfer_cmdbuf_ai);

    // -------------------------------------------------------
    // @Note: Setup vertex buffer

    vertex_buf_mem, _ := buffer_with_memory_make(VERTICES_SIZE, .TRANSFER_DST | .VERTEX_BUFFER, .DEVICE_LOCAL);
    defer buffer_with_memory_destroy(vertex_buf_mem);
    {
        // @Note: Making staging buffer for vertices
        staging_buf_mem, _ := buffer_with_memory_make(VERTICES_SIZE, .TRANSFER_SRC, .HOST_VISIBLE | .HOST_COHERENT);
        defer buffer_with_memory_destroy(staging_buf_mem);

        // @Note: Copy vertices data to staging buffer
        staging_data, _ := Vk.map_memory(device, staging_buf_mem.memory, offset = 0, size = VERTICES_SIZE);
        mem_copy(staging_data, VERTICES.data, VERTICES_SIZE);
        Vk.UnmapMemory(device, staging_buf_mem.memory);

        // @Note: Perform BufferCopy from staging buffer to device buffer
        _ := Vk.BeginCommandBuffer(transfer_cmdbuf, *Vk.CommandBufferBeginInfo.{});
        {
            buffer_copy := Vk.BufferCopy.{ size = VERTICES_SIZE };
            Vk.cmd_copy_buffer(transfer_cmdbuf, staging_buf_mem.buffer, vertex_buf_mem.buffer, .[buffer_copy]);
        }
        _ := Vk.EndCommandBuffer(transfer_cmdbuf);

        submit_info := Vk.SubmitInfo.{
            commandBufferCount = 1,
            pCommandBuffers    = *transfer_cmdbuf
        };
        Vk.queue_one_submit(transfer_queue, submit_info);
        Vk.QueueWaitIdle(transfer_queue);
    }

    // -------------------------------------------------------
    // @Note: Setup index buffer

    Vk.ResetCommandBuffer(transfer_cmdbuf, 0);

    index_buffer, _ := buffer_with_memory_make(INDICES_SIZE, .TRANSFER_DST | .INDEX_BUFFER, .DEVICE_LOCAL);
    defer buffer_with_memory_destroy(index_buffer);
    {
        // @Note: Making staging buffer for indices
        staging_buf_mem, _ := buffer_with_memory_make(INDICES_SIZE, .TRANSFER_SRC, .HOST_VISIBLE | .HOST_COHERENT);
        defer buffer_with_memory_destroy(staging_buf_mem);

        // @Note: Copy indices data to staging buffer
        staging_data, _ := Vk.map_memory(device, staging_buf_mem.memory, offset = 0, size = INDICES_SIZE);
        mem_copy(staging_data, INDICES.data, INDICES_SIZE);
        Vk.UnmapMemory(device, staging_buf_mem.memory);

        // @Note: Perform BufferCopy from staging buffer to device buffer
        _ := Vk.BeginCommandBuffer(transfer_cmdbuf, *Vk.CommandBufferBeginInfo.{});
        {
            buffer_copy := Vk.BufferCopy.{ size = INDICES_SIZE };
            Vk.cmd_copy_buffer(transfer_cmdbuf, staging_buf_mem.buffer, index_buffer.buffer, .[buffer_copy]);
        }
        _ := Vk.EndCommandBuffer(transfer_cmdbuf);

        submit_info := Vk.SubmitInfo.{
            commandBufferCount = 1,
            pCommandBuffers    = *transfer_cmdbuf
        };

        Vk.queue_one_submit(transfer_queue, submit_info);
        Vk.QueueWaitIdle(transfer_queue);
    }

    // -------------------------------------------------------
    // @Note: Setup matrix uniform buffers

    Uniform_Buffer :: struct {
        using buf_mem : Buffer_With_Memory;
        mapped        : *void;
    }

    matrix_uniform_buffers : [MAX_FRAMES_IN_FLIGHT]Uniform_Buffer;

    for * matrix_uniform_buffers {

        // @Note: Since these are going to change every frame, no point in making staging buffers for them.
        //        Therefore, no need to make them have .TRANSFER_DST or be .DEVICE_LOCAL

        it.buf_mem, _ = buffer_with_memory_make(size_of(Matrix_Uniforms), .UNIFORM_BUFFER, .HOST_VISIBLE | .HOST_COHERENT);
        it.mapped,  _ = Vk.map_memory(context.vk.device.handle, it.memory, offset = 0, size = size_of(Matrix_Uniforms));

        buffer_info := Vk.DescriptorBufferInfo.{
            buffer = it.buffer,
            offset = 0,
            range  = size_of(Matrix_Uniforms),
        };

        descriptor_write := Vk.WriteDescriptorSet.{
            dstSet           = descriptor_sets[it_index],
            dstBinding       = 0,
            dstArrayElement  = 0,
            descriptorType   = .UNIFORM_BUFFER,
            descriptorCount  = 1,
            pBufferInfo      = *buffer_info,
        };

        Vk.update_descriptor_sets(context.vk.device.handle, .[descriptor_write], .[]);
    }

    defer for matrix_uniform_buffers {
        Vk.UnmapMemory(context.vk.device.handle, it.memory);
        buffer_with_memory_destroy(it.buf_mem);
    }

    // -------------------------------------------------------
    // @Note: Setup swapchain

    context.vk.swapchain = swapchain_make(context.vk.device, context.vk.surface, WIDTH, HEIGHT);
    generate_swapchain_framebuffers(*context.vk.swapchain, context.vk.device, context.vk.render_pass);
    defer swapchain_destroy(context.vk.swapchain, context.vk.device);

    // -------------------------------------------------------
    // @Note: Create synchronization objects

    swapchain_image_sems : [MAX_FRAMES_IN_FLIGHT]Vk.Semaphore;
    render_finished_sems : [MAX_FRAMES_IN_FLIGHT]Vk.Semaphore;
    in_flight_fences     : [MAX_FRAMES_IN_FLIGHT]Vk.Fence;

    for range(MAX_FRAMES_IN_FLIGHT) {
        swapchain_image_sems[it], _ = Vk.create_semaphore(context.vk.device.handle, *Vk.SemaphoreCreateInfo.{});
        render_finished_sems[it], _ = Vk.create_semaphore(context.vk.device.handle, *Vk.SemaphoreCreateInfo.{});

        in_flight_fences[it], _ = Vk.create_fence(context.vk.device.handle, *Vk.FenceCreateInfo.{ flags = .SIGNALED });
    }

    defer for range(MAX_FRAMES_IN_FLIGHT) {
        Vk.DestroySemaphore(context.vk.device.handle, swapchain_image_sems[it], null);
        Vk.DestroySemaphore(context.vk.device.handle, render_finished_sems[it], null);
        Vk.DestroyFence(context.vk.device.handle, in_flight_fences[it], null);
    }

    // -------------------------------------------------------
    // @Note: Setup graphics command buffer

    gfx_cmdbuf_ai := Vk.CommandBufferAllocateInfo.{
        level              = .PRIMARY,
        commandPool        = gfx_cmdpool,
        commandBufferCount = MAX_FRAMES_IN_FLIGHT,
    };

    gfx_cmdbufs, _ := Vk.allocate_command_buffers(device, *gfx_cmdbuf_ai);

    // -------------------------------------------------------
    // @Note: Main loop

    current_frame_idx := 0;
    start_time        := get_time();
    current_time      : float64;

    camera_pos     := Vector3.{2, 2, 0};
    camera_forward := normalize(.{0, 0, 0} - camera_pos);
    camera_left    := normalize(cross_product(.{0, 0, 1}, camera_forward));
    camera_up      := cross_product(camera_forward, camera_left);
    camera_speed   := 0.01;

    while main_loop := true {
        swapchain := *context.vk.swapchain;

        current_time = get_time();
        dt := current_time - start_time;

        // -------------------------------------------------------
        // @Note: Handle resizes

        for Input.get_window_resizes() {
            if it.window != app_window then continue;
            if it.width <= 0 || it.height <= 0 then continue main_loop;

            width  := cast(u32) it.width;
            height := cast(u32) it.height;
            recreate_swapchain(swapchain, context.vk.device, context.vk.surface, context.vk.render_pass, width, height);
        }

        reset_temporary_storage();

        // -------------------------------------------------------
        // @Note: Handle input

        Input.update_window_events();
        for Input.events_this_frame {
            if it.type == {
                case .QUIT;
                    break main_loop;
                case .KEYBOARD;
                    if it.key_code == #char "Q" && it.modifier_flags.ctrl_pressed {
                        break main_loop;
                    }
            }
        }

        camera_pos_add := Vector3.{};

        if Input.input_button_states[#char "W"] == .DOWN then camera_pos_add +=  camera_forward;
        if Input.input_button_states[#char "S"] == .DOWN then camera_pos_add += -camera_forward;
        if Input.input_button_states[#char "A"] == .DOWN then camera_pos_add +=  camera_left;
        if Input.input_button_states[#char "D"] == .DOWN then camera_pos_add += -camera_left;
        if Input.input_button_states[#char "Z"] == .DOWN then camera_pos_add +=  camera_up;
        if Input.input_button_states[#char "X"] == .DOWN then camera_pos_add += -camera_up;

        camera_pos += normalize_or_zero(camera_pos_add) * camera_speed * dt;

        // -------------------------------------------------------

        in_flight_fence     := in_flight_fences    [current_frame_idx];
        swapchain_image_sem := swapchain_image_sems[current_frame_idx];
        render_finished_sem := render_finished_sems[current_frame_idx];
        cmdbuf              := gfx_cmdbufs         [current_frame_idx];

        // -------------------------------------------------------
        // @Note: Reset fences

        Vk.wait_for_one_fence(device, in_flight_fence);
        swapchain_image_idx, _ := Vk.acquire_next_image(device, swapchain.handle, semaphore = swapchain_image_sem);
        _ := Vk.reset_one_fence(device, in_flight_fence);

        // -------------------------------------------------------
        // @Note: Reset and begin command buffer

        _ := Vk.ResetCommandBuffer(cmdbuf, 0);
        _ := Vk.BeginCommandBuffer(cmdbuf, *Vk.CommandBufferBeginInfo.{});
        {
            CLEAR_VALUES :: Vk.ClearValue.[
                .{ color = .{ _float32 = .[0.2, 0.3, 0.3, 1.0] } },
            ];
            render_rect := Vk.Rect2D.{ offset = .{0, 0}, extent = swapchain.extent };

            // -------------------------------------------------------
            // @Note: Bind graphics pipeline and begin render pass

            Vk.CmdBindPipeline(cmdbuf, .GRAPHICS, gfx_pipeline);

            render_pass_bi := Vk.RenderPassBeginInfo.{
                renderPass      = context.vk.render_pass.handle,
                clearValueCount = CLEAR_VALUES.count,
                pClearValues    = CLEAR_VALUES.data,
                framebuffer     = swapchain.framebuffers[swapchain_image_idx],
                renderArea      = render_rect,
            };
            Vk.CmdBeginRenderPass(cmdbuf, *render_pass_bi, .INLINE);
            {
                // -------------------------------------------------------
                // @Note: Set viewport and scissor

                viewport := Vk.Viewport.{
                    x        = 0.0,
                    y        = 0.0,
                    width    = cast(float) swapchain.width,
                    height   = cast(float) swapchain.height,
                    minDepth = 0.0,
                    maxDepth = 1.0,
                };
                Vk.cmd_set_one_viewport(cmdbuf, viewport);
                Vk.cmd_set_one_scissor(cmdbuf, render_rect);

                // -------------------------------------------------------
                // @Note: Bind index and vertex buffers and draw

                Vk.cmd_bind_one_vertex_buffer(cmdbuf, vertex_buf_mem.buffer);
                Vk.cmd_bind_index_buffer(cmdbuf, index_buffer.buffer);
                Vk.cmd_bind_one_descriptor_set(cmdbuf, .GRAPHICS, pipeline_layout, descriptor_sets[current_frame_idx]);

                Vk.cmd_draw_indexed(cmdbuf, INDICES.count);
            }
            Vk.CmdEndRenderPass(cmdbuf);

        }
        _ := Vk.EndCommandBuffer(cmdbuf);

        // -------------------------------------------------------
        // @Note: Update matrix uniform buffer

        aspect := cast(float) swapchain.width / swapchain.height;

        q : Quaternion;
        set_from_axis_and_angle(*q, .{0, 1, 0}, cast(float) (current_time * (PI / 2))); // @Note: Radians

        perspective_lh_zo :: (fov_y : float, aspect : float, near : float, far : float) -> Matrix4 {
            // @Note: https://github.com/g-truc/glm/blob/master/glm/ext/matrix_clip_space.inl#L265-L278
            tan_half_fov_y := tan(fov_y * 0.5);

            result : Matrix4;
            result._11 = 1.0 / (aspect * tan_half_fov_y);
            result._22 = 1.0 / (tan_half_fov_y);
            result._33 = far / (far - near);
            result._34 = 1.0;
            result._43 = -(far * near) / (far - near);

            return result;
        }

        look_at_lh :: (eye : Vector3, center : Vector3, up_ref := Vector3.{0, 0, 1}) -> Matrix4 {
            // @Note: https://github.com/g-truc/glm/blob/master/glm/ext/matrix_transform.inl#L176-L196
            forward := normalize(center - eye);
            left    := normalize(cross_product(up_ref, forward));
            up      := cross_product(forward, left);

            result := make_matrix_from_columns(left, up, forward);
            result._41 = -dot_product(left, eye);
            result._42 = -dot_product(up, eye);
            result._43 = -dot_product(forward, eye);

            return result;
        }

        matrix_uniforms := Matrix_Uniforms.{
            model = rotation_matrix(Matrix4, q),
            view  = look_at_lh(camera_pos, camera_forward),
            proj  = perspective_lh_zo(45.0 * (PI / 2), aspect, 0.1, 100.0),
        };
        mem_copy(matrix_uniform_buffers[current_frame_idx].mapped, *matrix_uniforms, size_of(Matrix_Uniforms));

        // -------------------------------------------------------
        // @Note: Submit to graphics queue

        wait_dst_stage_mask := Vk.PipelineStageFlags.COLOR_ATTACHMENT_OUTPUT;
        submit_info := Vk.SubmitInfo.{
            commandBufferCount   = 1,
            pCommandBuffers      = *cmdbuf,
            waitSemaphoreCount   = 1,
            pWaitSemaphores      = *swapchain_image_sem,
            pWaitDstStageMask    = *wait_dst_stage_mask,
            signalSemaphoreCount = 1,
            pSignalSemaphores    = *render_finished_sem,
        };
        Vk.queue_one_submit(gfx_queue, submit_info, in_flight_fence);

        // -------------------------------------------------------
        // @Note: Present swapchain using present queue

        present_info := Vk.PresentInfoKHR.{
            waitSemaphoreCount = 1,
            pWaitSemaphores    = *render_finished_sem,
            swapchainCount     = 1,
            pSwapchains        = *swapchain.handle,
            pImageIndices      = *swapchain_image_idx,
        };

        _ := Vk.QueuePresentKHR(present_queue, *present_info);

        current_frame_idx = (current_frame_idx + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    // @Note: Let the device finish any remaning operations before cleaning up resources
    Vk.DeviceWaitIdle(device);
}

// -------------------------------------------------------

// @Note: see assets/shaders/_generated_shader_table.jai
#placeholder shader_table;

// -------------------------------------------------------

#load "context.jai";
#load "utils.jai";
#load "vulkan.jai";

// -------------------------------------------------------

Vk :: #import,file "vk_wrapper.jai";

#import "Enum_Array";

Input  :: #import "Input";
Window :: #import "Window_Creation";
Win32  :: #import "Windows";

#import "Basic";
#import "File";
#import "Math";
#import "Print_Color";
#import "Sloppy_Math";
#import "Windows_Utf8";

using,except(Table) HT :: #import "Hash_Table";
Hash_Table :: HT.Table;
