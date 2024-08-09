// TODO:
// - [x] Test on Linux?
//   - [x] Generate linux vk bindings
//   - [x] Platform layer code
// - [ ] Check result values of Vk calls
// - [ ] Better physical device selection
// - [ ] Better assert proc (Stop relying on Debug module)
//

// -------------------------------------------------------

window_width  := 800;
window_height := 600;
window_title  := #run tprint("Vulkan (%)", DRAW_CMD);

// -------------------------------------------------------

Vertex :: struct {
    position : Vector3;  @Binding=0 @Location=1
    color    : Vector3;  @Binding=0 @Location=2
    uv       : Vector2;  @Binding=0 @Location=3
}

Uniform_Matrices :: struct {
    model := Matrix4_Identity #align 16;
    view  := Matrix4_Identity #align 16;
    proj  := Matrix4_Identity #align 16;
}

// -------------------------------------------------------

DRAW_CMD : enum {
    CmdDraw;
    CmdDrawInstanced;
    CmdDrawIndexed;
    CmdDrawIndexedInstanced;
} : .CmdDrawIndexedInstanced;

#if DRAW_CMD == .CmdDraw || DRAW_CMD == .CmdDrawInstanced {
    VERTICES :: Vertex.[
        .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 0
        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 1
        .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 2
        .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 2
        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 3
        .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 0

        .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 4
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 5
        .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 6
        .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 6
        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 7
        .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 4

        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 8
        .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 9
        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 10
        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 10
        .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 11
        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 8

        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 12
        .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 13
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 14
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 14
        .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 15
        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 12

        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 16
        .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 17
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 18
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 18
        .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 19
        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 16

        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 20
        .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 21
        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 22
        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 22
        .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 23
        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 24
    ];

    INDICES :: u32.[0];
}
else #if DRAW_CMD == .CmdDrawIndexed || DRAW_CMD == .CmdDrawIndexedInstanced {
    VERTICES :: Vertex.[
        .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 0
        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 1
        .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 2
        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 3

        .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 4
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 5
        .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 6
        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 7

        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 8
        .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 9
        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 10
        .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 11

        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 12
        .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 13
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 14
        .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 15

        .{ position = .{ -0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 16
        .{ position = .{ -0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 17
        .{ position = .{  0.5, -0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 18
        .{ position = .{  0.5, -0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 19

        .{ position = .{  0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 0.0 } }, // 20
        .{ position = .{  0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 0.0, 1.0 } }, // 21
        .{ position = .{ -0.5,  0.5,  0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 1.0 } }, // 22
        .{ position = .{ -0.5,  0.5, -0.5 }, color = .{ 1.0, 1.0, 1.0 }, uv = .{ 1.0, 0.0 } }, // 23
    ];

    INDICES :: u32.[
         0,  1,  2,  2,  3,  0,
         4,  5,  6,  6,  7,  4,
         8,  9, 10, 10, 11,  8,
        12, 13, 14, 14, 15, 12,
        16, 17, 18, 18, 19, 16,
        20, 21, 22, 22, 23, 20,
    ];
}

VERTICES_SIZE_BYTES :: size_of(type_of(VERTICES));
INDICES_SIZE_BYTES  :: size_of(type_of(INDICES));

// -------------------------------------------------------

MAX_FRAMES_IN_FLIGHT :: 2;

// -------------------------------------------------------

main :: () {
    setup_context(highest_logger_level = .Debug, logger_flags = .Level);

    // -------------------------------------------------------
    // @Note: Create window

    app_window := Window.create_window(window_width, window_height, window_title);

    // -------------------------------------------------------
    // @Note: Load vulkan dll and load global commands

    context.vk.module = load_vulkan_lib();
    defer unload_vulkan_lib();

    log_debug("Loading global proc addresses...");
    Vk.load_global_proc_addresses(vulkan_proc_loader);

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
        log_trace("Create instance = %%");
        context.vk.instance.handle = instance;
    }

    defer Vk.destroy_instance(context.vk.instance.handle);

    log_debug("Loading instance proc addresses...");
    Vk.load_instance_proc_addresses(context.vk.instance.handle);

    debug_messenger, _ := Vk.create_debug_utils_messenger(context.vk.instance.handle, *debug_messenger_ci);
    log_trace("Create debug utils messenger = %%");
    defer Vk.destroy_debug_utils_messenger(context.vk.instance.handle, debug_messenger);

    // -------------------------------------------------------
    // @Note: Create vulkan surface

    #if OS == .WINDOWS {
        Win32 :: #import "Windows";
        hinstance  := Win32.GetModuleHandleW(null);  // @Todo: Add GetModuleHandleExW to Windows module
        surface_ci := Vk.Win32SurfaceCreateInfoKHR.{
            hinstance = hinstance,
            hwnd      = app_window,
        };

        surface, _ := Vk.create_win32_surface(context.vk.instance.handle, *surface_ci);
        log_trace("Create Win32 surface = %%");
        context.vk.surface.handle = surface;
    }
    else #if OS == .LINUX {
        X11 :: #import "X11";
        surface_ci := Vk.XlibSurfaceCreateInfoKHR.{
            dpy    = X11.x_global_display,
            window = app_window,
        };

        surface, _ := Vk.create_xlib_surface(context.vk.instance.handle, *surface_ci);
        log_trace("Create Xlib surface = %%");
        context.vk.surface.handle = surface;
    }
    defer Vk.destroy_surface(context.vk.instance.handle, context.vk.surface.handle);

    // -------------------------------------------------------
    // @Note: Get the best physical device to create a logical device from

    {
        available_physical_devices, _ := Vk.enumerate_physical_devices(context.vk.instance.handle);
        defer array_free(available_physical_devices);
        assert(available_physical_devices.count > 0, "Physical device with Vulkan support not found!");

        // @Note: For now just pick the first GPU we find that has all the things we need.
        //        Later we can pick the best one, or make a UI system to pick the GPU.
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

            context.vk.device.physical_device = pd;
            break;
        }

        assert(context.vk.device.physical_device != null, "Suitable physical device not found!\n");
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

        device, _ := Vk.create_device(context.vk.device.physical_device, *device_ci);
        log_trace("Create device = %%");
        context.vk.device.handle = device;
    }

    defer Vk.destroy_device(context.vk.device.handle);

    log_debug("Loading device proc addresses...");
    Vk.load_device_proc_addresses(context.vk.device.handle);

    gfx_queue      := Vk.get_device_queue(context.vk.device.handle, context.vk.device.queue_family_indices[Queue_Family_Index_Type.Graphics], 0);
    transfer_queue := Vk.get_device_queue(context.vk.device.handle, context.vk.device.queue_family_indices[Queue_Family_Index_Type.Transfer], 0);
    present_queue  := Vk.get_device_queue(context.vk.device.handle, context.vk.device.queue_family_indices[Queue_Family_Index_Type.Present],  0);

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
        log_debug("Surface format: Format = % | Color space = %", context.vk.surface.format.format, context.vk.surface.format.colorSpace);
    }

    // -------------------------------------------------------
    // @Note: Find best depth format
    {
        DEPTH_FORMATS :: Vk.Format.[.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT];
        for DEPTH_FORMATS {
            format_properties := Vk.get_physical_device_format_properties(context.vk.device.physical_device, it);
            if format_properties.optimalTilingFeatures & .DEPTH_STENCIL_ATTACHMENT == .DEPTH_STENCIL_ATTACHMENT {
                context.vk.device.depth_format = it;
                break;
            }
            else if format_properties.linearTilingFeatures & .DEPTH_STENCIL_ATTACHMENT == .DEPTH_STENCIL_ATTACHMENT {
                context.vk.device.depth_format = it;
                break;
            }
        }
        log_debug("Depth image format: %", context.vk.device.depth_format);
    }

    // -------------------------------------------------------
    // @Note: Setup render pass

    context.vk.render_pass = render_pass_make(context.vk.device, context.vk.surface);
    defer render_pass_destroy(context.vk.device, context.vk.render_pass);

    // -------------------------------------------------------
    // @Note: Create shader modules

    log_debug("Loading vertex shader...");
    log_indent();
    vert_shader_bin : string;
    {
        shader_name :: "triangle.vert";

        shader_path, success := table_find(*asset_table, shader_name);
        assert(success, "Could not find shader \"%\" in asset table!", shader_name);
        log_debug("Loading shader binary \"%\" (\"%\")", shader_name, shader_path);

        vert_shader_bin, success = read_entire_file(shader_path);
        assert(success, "Could not read shader binary from \"%\"!", shader_path);
    }
    defer free(vert_shader_bin);

    vert_shader_module_ci := Vk.ShaderModuleCreateInfo.{
        codeSize = cast(u64)  vert_shader_bin.count,
        pCode    = cast(*u32) vert_shader_bin.data,
    };
    vert_shader_module, _ := Vk.create_shader_module(context.vk.device.handle, *vert_shader_module_ci);
    log_trace("Create shader module = %%");
    defer Vk.destroy_shader_module(context.vk.device.handle, vert_shader_module);
    log_unindent();

    log_debug("Loading fragment shader...");
    log_indent();
    frag_shader_bin : string;
    {
        shader_name :: "triangle.frag";

        shader_path, success := table_find(*asset_table, shader_name);
        assert(success, "Could not find shader \"%\" in asset table!", shader_name);
        log_debug("Loading shader binary \"%\" (\"%\")", shader_name, shader_path);

        frag_shader_bin, success = read_entire_file(shader_path);
        assert(success, "Could not read shader binary from \"%\"!", shader_path);
    }
    defer free(frag_shader_bin);

    frag_shader_module_ci := Vk.ShaderModuleCreateInfo.{
        codeSize = cast(u64)  frag_shader_bin.count,
        pCode    = cast(*u32) frag_shader_bin.data,
    };
    frag_shader_module, _ := Vk.create_shader_module(context.vk.device.handle, *frag_shader_module_ci);
    log_trace("Create shader module = %%");
    defer Vk.destroy_shader_module(context.vk.device.handle, frag_shader_module);
    log_unindent();


    vert_shader_stage_ci := Vk.PipelineShaderStageCreateInfo.{
        stage  = .VERTEX,
        module = vert_shader_module,
        pName  = "main",
    };
    frag_shader_stage_ci := Vk.PipelineShaderStageCreateInfo.{
        stage  = .FRAGMENT,
        module = frag_shader_module,
        pName  = "main",
    };

    pipeline_shader_stages := Vk.PipelineShaderStageCreateInfo.[vert_shader_stage_ci, frag_shader_stage_ci];

    // -------------------------------------------------------
    // @Note: Setup descriptor set layout

    descriptor_set_layout_bindings := Vk.DescriptorSetLayoutBinding.[
        .{
            binding            = 0,
            descriptorType     = .UNIFORM_BUFFER,
            descriptorCount    = 1,
            stageFlags         = .VERTEX,
            pImmutableSamplers = null,
        },
        .{
            binding            = 1,
            descriptorType     = .COMBINED_IMAGE_SAMPLER,
            descriptorCount    = 1,
            stageFlags         = .FRAGMENT,
            pImmutableSamplers = null,
        },
    ];

    descriptor_set_layout_ci := Vk.DescriptorSetLayoutCreateInfo.{
        bindingCount = descriptor_set_layout_bindings.count,
        pBindings    = descriptor_set_layout_bindings.data,
    };

    descriptor_set_layout, _ := Vk.create_descriptor_set_layout(context.vk.device.handle, *descriptor_set_layout_ci);
    log_trace("Create descriptor set layout = %%");
    defer Vk.destroy_descriptor_set_layout(context.vk.device.handle, descriptor_set_layout);

    // -------------------------------------------------------
    // @Note: Setup descriptor pool and descriptor sets

    descriptor_pool_sizes := NewArray(descriptor_set_layout_bindings.count, Vk.DescriptorPoolSize);
    for * descriptor_set_layout_bindings {
         descriptor_pool_sizes[it_index] = .{
            type            = it.descriptorType,
            descriptorCount = MAX_FRAMES_IN_FLIGHT,
        };
    }

    descriptor_pool_ci := Vk.DescriptorPoolCreateInfo.{
        poolSizeCount = cast(u32) descriptor_pool_sizes.count,
        pPoolSizes    = descriptor_pool_sizes.data,
        maxSets       = MAX_FRAMES_IN_FLIGHT,
        flags         = 0,
    };

    descriptor_pool, _ := Vk.create_descriptor_pool(context.vk.device.handle, *descriptor_pool_ci);
    log_trace("Create descriptor pool = %%");
    defer Vk.destroy_descriptor_pool(context.vk.device.handle, descriptor_pool);

    set_layouts : [MAX_FRAMES_IN_FLIGHT]Vk.DescriptorSetLayout = .[descriptor_set_layout, descriptor_set_layout];

    descriptor_set_ai := Vk.DescriptorSetAllocateInfo.{
        descriptorPool     = descriptor_pool,
        descriptorSetCount = set_layouts.count,
        pSetLayouts        = set_layouts.data,
    };

    descriptor_sets, _ := Vk.allocate_descriptor_sets(context.vk.device.handle, *descriptor_set_ai);
    log_trace("Allocate descriptor sets = %%");

    // -------------------------------------------------------
    // @Note: Setup pipeline layout

    pipeline_layout_ci := Vk.PipelineLayoutCreateInfo.{
        setLayoutCount         = 1,
        pSetLayouts            = *descriptor_set_layout,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = null,
    };
    pipeline_layout, _ := Vk.create_pipeline_layout(context.vk.device.handle, *pipeline_layout_ci);
    log_trace("Create pipeline layout = %%");
    defer Vk.destroy_pipeline_layout(context.vk.device.handle, pipeline_layout);

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

    #insert -> string {
        builder : String_Builder;
        append(*builder, "vertex_input_attribute_descs := Vk.VertexInputAttributeDescription.[\n");

        members := (cast(*Type_Info_Struct) Vertex).members;
        for member : members {
            binding, location, format : string;
            for note : member.notes {
                BINDING  :: "Binding=";
                LOCATION :: "Location=";

                if starts_with(note, BINDING) {
                    binding = string.{note.count - BINDING.count, note.data + BINDING.count};
                }
                if starts_with(note, LOCATION) {
                    location = string.{note.count - LOCATION.count, note.data + LOCATION.count};
                }
            }

            if member.type == cast(*Type_Info) Vector2 {
                format = "R32G32_SFLOAT";
            }
            else if member.type == cast(*Type_Info) Vector3 {
                format = "R32G32B32_SFLOAT";
            }
            else {
                assert(false, "Unhandled type \"%\"!", member.type);
            }

            print_to_builder(*builder, ".{ binding = %, location = %, format = .%, offset = % },\n", binding, location, format, member.offset_in_bytes);
        }

        append(*builder, "];\n");
        return builder_to_string(*builder);
    }

    // vertex_input_attribute_descs := Vk.VertexInputAttributeDescription.[
    //     .{ binding = 0, location = 0, format = .R32G32B32_SFLOAT, offset = cast(u32) offset_of(Vertex, "position") },
    //     .{ binding = 0, location = 1, format = .R32G32B32_SFLOAT, offset = cast(u32) offset_of(Vertex, "color"   ) },
    //     .{ binding = 0, location = 2, format = .R32G32\  _SFLOAT, offset = cast(u32) offset_of(Vertex, "uv"      ) },
    // ];
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
        cullMode                = .BACK,
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
        depthTestEnable       = .TRUE,
        depthWriteEnable      = .TRUE,
        depthCompareOp        = .LESS,
        depthBoundsTestEnable = .FALSE,
        minDepthBounds        = 0.0,
        maxDepthBounds        = 1.0,
        stencilTestEnable     = .FALSE,
        front                 = .{},
        back                  = .{},
    };

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

    gfx_pipeline, _ := Vk.create_one_graphics_pipeline(context.vk.device.handle, *gfx_pipeline_ci);
    log_trace("Create graphics pipeline = %%");
    defer Vk.destroy_pipeline(context.vk.device.handle, gfx_pipeline);

    // -------------------------------------------------------
    // @Note: Setup command pools

    gfx_cmdpool_ci := Vk.CommandPoolCreateInfo.{
        flags            = .RESET_COMMAND_BUFFER,
        queueFamilyIndex = context.vk.device.queue_family_indices[Queue_Family_Index_Type.Graphics],
    };
    gfx_cmdpool, _ := Vk.create_command_pool(context.vk.device.handle, *gfx_cmdpool_ci);
    log_trace("Create graphics command pool = %%");
    defer Vk.destroy_command_pool(context.vk.device.handle, gfx_cmdpool);

    transfer_cmdpool_ci := Vk.CommandPoolCreateInfo.{
        flags            = .RESET_COMMAND_BUFFER,
        queueFamilyIndex = context.vk.device.queue_family_indices[Queue_Family_Index_Type.Transfer],
    };
    transfer_cmdpool, _ := Vk.create_command_pool(context.vk.device.handle, *transfer_cmdpool_ci);
    log_trace("Create transfer command pool = %%");
    defer Vk.destroy_command_pool(context.vk.device.handle, transfer_cmdpool);

    // -------------------------------------------------------
    // @Note: Setup graphics and transfer command buffers

    gfx_cmdbuf_ai := Vk.CommandBufferAllocateInfo.{
        level              = .PRIMARY,
        commandPool        = gfx_cmdpool,
        commandBufferCount = MAX_FRAMES_IN_FLIGHT,
    };

    gfx_cmdbufs, _ := Vk.allocate_command_buffers(context.vk.device.handle, *gfx_cmdbuf_ai);
    log_trace("Allocate graphics command buffers = %%");

    transfer_cmdbuf_ai := Vk.CommandBufferAllocateInfo.{
        commandPool = transfer_cmdpool,
        level       = .PRIMARY,
    };
    transfer_cmdbuf, _ := Vk.allocate_one_command_buffer(context.vk.device.handle, *transfer_cmdbuf_ai);
    log_trace("Allocate transfer command buffer = %%");

    // -------------------------------------------------------
    // @Note: Setup texture

    log_debug("Loading texture...");
    log_indent();

    image_pixels  : *u8;
    image_width, image_height : u32;
    {
        image_name :: "container";

        image_path, success := table_find(*asset_table, image_name);
        assert(success, "Could not find texture \"%\" in asset table!", image_name);
        log_debug("Loading image \"%\" (\"%\")", image_name, image_path);

        image_pixels, image_width, image_height = image_load(image_path);
        assert(
            image_pixels != null && image_width != 0 && image_height != 0,
            "Could not load image \"%\" from \"%\"! (width = %, height = %, pixels = %)",
            image_name, image_path, image_width, image_height, image_pixels
        );
    }

    texture_image, _ := image_make(image_width, image_height, .R8G8B8A8_UNORM, .OPTIMAL, .TRANSFER_DST | .SAMPLED, .DEVICE_LOCAL);
    image_view_make(*texture_image, .COLOR);
    defer image_destroy(texture_image);
    {
        log_trace("Copying image memory from buffer...");
        log_indent_scope();

        image_size := cast(s64) (image_width * image_height * 4);
        staging_buf_mem, _ := buffer_with_memory_make(cast(Vk.DeviceSize) image_size, .TRANSFER_SRC, .HOST_VISIBLE | .HOST_COHERENT);
        defer buffer_with_memory_destroy(staging_buf_mem);

        staging_data, _ := Vk.map_memory(context.vk.device.handle, staging_buf_mem.memory, offset = 0, size = cast(Vk.DeviceSize) image_size);
        log_trace("Map staging buffer memory = %%");

        mem_copy(staging_data, image_pixels, image_size);
        Vk.unmap_memory(context.vk.device.handle, staging_buf_mem.memory);

        // @Note: Using graphics queue because you can't transition to shader read in transfer queue
        _ := Vk.ResetCommandBuffer(gfx_cmdbufs[0], 0);
        log_trace("Reset graphics command buffer = %%");
        _ := Vk.BeginCommandBuffer(gfx_cmdbufs[0], *(Vk.CommandBufferBeginInfo.{}));
        log_trace("Begin graphics command buffer = %%");
        {
            // @Note: Transition image layout to transfer dst
            start_to_transfer_barrier := Vk.ImageMemoryBarrier.{
                image            = texture_image.image,
                oldLayout        = .UNDEFINED,
                newLayout        = .TRANSFER_DST_OPTIMAL,
                srcAccessMask    = 0,
                dstAccessMask    = .TRANSFER_WRITE,
                subresourceRange = .{
                    aspectMask     = .COLOR,
                    baseMipLevel   = 0,
                    levelCount     = 1,
                    baseArrayLayer = 0,
                    layerCount     = 1,
                },

                srcQueueFamilyIndex = Vk.QUEUE_FAMILY_IGNORED,
                dstQueueFamilyIndex = Vk.QUEUE_FAMILY_IGNORED,
            };
            Vk.cmd_pipeline_barrier(gfx_cmdbufs[0], .TOP_OF_PIPE, .TRANSFER, image_memory_barriers = .[start_to_transfer_barrier]);

            // @Note: Copy buffer data to image
            buffer_image_copy := Vk.BufferImageCopy.{
                bufferOffset      = 0,
                bufferRowLength   = 0,
                bufferImageHeight = 0,
                imageOffset       = .{0, 0, 0},
                imageExtent       = .{image_width, image_height, 1},
                imageSubresource  = .{
                    aspectMask     = .COLOR,
                    mipLevel       = 0,
                    baseArrayLayer = 0,
                    layerCount     = 1,
                },
            };
            Vk.cmd_copy_buffer_to_image(gfx_cmdbufs[0], staging_buf_mem.buffer, texture_image.image, .TRANSFER_DST_OPTIMAL, .[buffer_image_copy]);

            // @Note: Transition image layout to shader read only
            transfer_to_shader_barrier := Vk.ImageMemoryBarrier.{
                image            = texture_image.image,
                oldLayout        = .TRANSFER_DST_OPTIMAL,
                newLayout        = .SHADER_READ_ONLY_OPTIMAL,
                srcAccessMask    = .TRANSFER_WRITE,
                dstAccessMask    = .SHADER_READ,
                subresourceRange = .{
                    aspectMask     = .COLOR,
                    baseMipLevel   = 0,
                    levelCount     = 1,
                    baseArrayLayer = 0,
                    layerCount     = 1,
                },

                srcQueueFamilyIndex = Vk.QUEUE_FAMILY_IGNORED,
                dstQueueFamilyIndex = Vk.QUEUE_FAMILY_IGNORED,
            };
            Vk.cmd_pipeline_barrier(gfx_cmdbufs[0], .TRANSFER, .FRAGMENT_SHADER, image_memory_barriers = .[transfer_to_shader_barrier]);
        }
        _ := Vk.EndCommandBuffer(gfx_cmdbufs[0]);
        log_trace("End graphics command buffer = %%");

        submit_info := Vk.SubmitInfo.{
            commandBufferCount = 1,
            pCommandBuffers    = *gfx_cmdbufs[0]
        };
        _ := Vk.queue_one_submit(gfx_queue, submit_info);
        log_trace("Graphics queue submit = %%");
        _ := Vk.QueueWaitIdle(gfx_queue);
        log_trace("Graphics queue wait idle = %%");
    }

    // @Note: don't need this anymore, after copying
    stbi_image_free(image_pixels);

    // -------------------------------------------------------
    // @Note: Create texture sampler

    texture_sampler_ci := Vk.SamplerCreateInfo.{
        magFilter               = .LINEAR,
        minFilter               = .LINEAR,
        addressModeU            = .REPEAT,
        addressModeV            = .REPEAT,
        addressModeW            = .REPEAT,
        mipmapMode              = .LINEAR,
        mipLodBias              = 0.0,
        minLod                  = 0.0,
        maxLod                  = 0.0,
        anisotropyEnable        = .TRUE,
        maxAnisotropy           = context.vk.device.limits.maxSamplerAnisotropy,
        borderColor             = .INT_OPAQUE_BLACK,
        unnormalizedCoordinates = .FALSE,
        compareEnable           = .FALSE,
        compareOp               = .ALWAYS,
    };
    texture_sampler, _ := Vk.create_sampler(context.vk.device.handle, *texture_sampler_ci);
    log_trace("Create texture sampler = %%");
    defer Vk.destroy_sampler(context.vk.device.handle, texture_sampler);
    log_unindent();

    // -------------------------------------------------------
    // @Note: Setup vertex buffer

    log_debug("Creating vertex buffer...");
    log_indent();

    vertex_buf_mem, _ := buffer_with_memory_make(VERTICES_SIZE_BYTES, .TRANSFER_DST | .VERTEX_BUFFER, .DEVICE_LOCAL);
    defer buffer_with_memory_destroy(vertex_buf_mem);
    {
        log_trace("Copying vertex buffer data...");
        log_indent_scope();

        // @Note: Making staging buffer for vertices
        staging_buf_mem, _ := buffer_with_memory_make(VERTICES_SIZE_BYTES, .TRANSFER_SRC, .HOST_VISIBLE | .HOST_COHERENT);
        defer buffer_with_memory_destroy(staging_buf_mem);

        // @Note: Copy vertices data to staging buffer
        staging_data, _ := Vk.map_memory(context.vk.device.handle, staging_buf_mem.memory, offset = 0, size = VERTICES_SIZE_BYTES);
        log_trace("Map staging buffer memory = %%");
        mem_copy(staging_data, VERTICES.data, VERTICES_SIZE_BYTES);
        Vk.unmap_memory(context.vk.device.handle, staging_buf_mem.memory);

        // @Note: Perform BufferCopy from staging buffer to device buffer
        _ := Vk.ResetCommandBuffer(transfer_cmdbuf, 0);
        log_trace("Reset transfer command buffer = %%");
        _ := Vk.BeginCommandBuffer(transfer_cmdbuf, *(Vk.CommandBufferBeginInfo.{}));
        log_trace("Begin transfer command buffer = %%");
        {
            buffer_copy := Vk.BufferCopy.{ size = VERTICES_SIZE_BYTES };
            Vk.cmd_copy_buffer(transfer_cmdbuf, staging_buf_mem.buffer, vertex_buf_mem.buffer, .[buffer_copy]);
        }
        _ := Vk.EndCommandBuffer(transfer_cmdbuf);
        log_trace("End transfer command buffer = %%");

        submit_info := Vk.SubmitInfo.{
            commandBufferCount = 1,
            pCommandBuffers    = *transfer_cmdbuf
        };
        _ := Vk.queue_one_submit(transfer_queue, submit_info);
        log_trace("Transfer queue submit = %%");
        _ := Vk.QueueWaitIdle(transfer_queue);
        log_trace("Transfer queue wait idle = %%");
    }
    log_unindent();

    // -------------------------------------------------------
    // @Note: Setup index buffer

    log_debug("Creating index buffer...");
    log_indent();

    index_buffer, _ := buffer_with_memory_make(INDICES_SIZE_BYTES, .TRANSFER_DST | .INDEX_BUFFER, .DEVICE_LOCAL);
    defer buffer_with_memory_destroy(index_buffer);
    {
        log_trace("Copying index buffer data...");
        log_indent_scope();

        // @Note: Making staging buffer for indices
        staging_buf_mem, _ := buffer_with_memory_make(INDICES_SIZE_BYTES, .TRANSFER_SRC, .HOST_VISIBLE | .HOST_COHERENT);
        defer buffer_with_memory_destroy(staging_buf_mem);

        // @Note: Copy indices data to staging buffer
        staging_data, _ := Vk.map_memory(context.vk.device.handle, staging_buf_mem.memory, offset = 0, size = INDICES_SIZE_BYTES);
        log_trace("Map staging buffer memory = %%");
        mem_copy(staging_data, INDICES.data, INDICES_SIZE_BYTES);
        Vk.unmap_memory(context.vk.device.handle, staging_buf_mem.memory);

        // @Note: Perform BufferCopy from staging buffer to device buffer
        _ := Vk.ResetCommandBuffer(transfer_cmdbuf, 0);
        log_trace("Reset transfer command buffer = %%");
        _ := Vk.BeginCommandBuffer(transfer_cmdbuf, *(Vk.CommandBufferBeginInfo.{}));
        log_trace("Begin transfer command buffer = %%");
        {
            buffer_copy := Vk.BufferCopy.{ size = INDICES_SIZE_BYTES };
            Vk.cmd_copy_buffer(transfer_cmdbuf, staging_buf_mem.buffer, index_buffer.buffer, .[buffer_copy]);
        }
        _ := Vk.EndCommandBuffer(transfer_cmdbuf);
        log_trace("End transfer command buffer = %%");

        submit_info := Vk.SubmitInfo.{
            commandBufferCount = 1,
            pCommandBuffers    = *transfer_cmdbuf
        };
        _ := Vk.queue_one_submit(transfer_queue, submit_info);
        log_trace("Transfer queue submit = %%");
        _ := Vk.QueueWaitIdle(transfer_queue);
        log_trace("Transfer queue wait idle = %%");
    }
    log_unindent();

    // -------------------------------------------------------
    // @Note: Setup uniforms

    Uniform_Buffer :: struct {
        using buf_mem : Buffer_With_Memory;
        mapped        : *void;
    }

    matrix_uniform_buffers : [MAX_FRAMES_IN_FLIGHT]Uniform_Buffer;

    log_debug("Setting up uniforms (%) ...", MAX_FRAMES_IN_FLIGHT);
    log_indent();
    for range(MAX_FRAMES_IN_FLIGHT) {
        descriptor_writes := NewArray(descriptor_set_layout_bindings.count, Vk.WriteDescriptorSet);

        log_trace("(%) Creating descriptor writes (%) ...", it, descriptor_writes.count);
        for binding, bi : descriptor_set_layout_bindings {
            log_indent_scope();

            if binding.descriptorType == {
                case .UNIFORM_BUFFER;
                    log_trace("(%) Creating uniform buffer...", bi);
                    log_indent_scope();

                    // @Note: Since these are going to change every frame, no point in making staging buffers for them.
                    //        Therefore, no need to make them be .TRANSFER_DST or .DEVICE_LOCAL
                    matrix_uniform_buffers[it].buf_mem, _ = buffer_with_memory_make(size_of(Uniform_Matrices), .UNIFORM_BUFFER, .HOST_VISIBLE | .HOST_COHERENT);
                    matrix_uniform_buffers[it].mapped,  _ = Vk.map_memory(context.vk.device.handle, matrix_uniform_buffers[it].memory, offset = 0, size = size_of(Uniform_Matrices));
                    log_trace("Map matrix uniform memory = %%");

                    buffer_info := Vk.DescriptorBufferInfo.{
                        buffer = matrix_uniform_buffers[it].buffer,
                        offset = 0,
                        range  = size_of(Uniform_Matrices),
                    };

                    descriptor_writes[bi] = .{
                        dstSet           = descriptor_sets[it],
                        dstBinding       = binding.binding,
                        dstArrayElement  = 0,
                        descriptorType   = binding.descriptorType,
                        descriptorCount  = binding.descriptorCount,
                        pBufferInfo      = *buffer_info, // @Volatile!!
                    };

                case .COMBINED_IMAGE_SAMPLER;
                    log_trace("(%) Creating image sampler...", bi);
                    log_indent_scope();

                    image_info := Vk.DescriptorImageInfo.{
                        imageLayout = .SHADER_READ_ONLY_OPTIMAL,
                        imageView   = texture_image.view,
                        sampler     = texture_sampler,
                    };

                    descriptor_writes[bi] = .{
                        dstSet           = descriptor_sets[it],
                        dstBinding       = binding.binding,
                        dstArrayElement  = 0,
                        descriptorType   = binding.descriptorType,
                        descriptorCount  = binding.descriptorCount,
                        pImageInfo       = *image_info, // @Volatile!!
                    };

                case;
                    assert(false, "Unhandled descriptor type %!", binding.descriptorType);
            }
        }

        log_trace("(%) Updating descriptor sets...", it);
        Vk.update_descriptor_sets(context.vk.device.handle, writes = descriptor_writes);
    }
    log_unindent();

    defer for matrix_uniform_buffers {
        Vk.unmap_memory(context.vk.device.handle, it.memory);
        buffer_with_memory_destroy(it.buf_mem);
    }

    // -------------------------------------------------------
    // @Note: Setup swapchain

    swapchain_make(window_width, window_height);
    defer swapchain_destroy();

    // -------------------------------------------------------
    // @Note: Create synchronization objects

    frame_syncs : [MAX_FRAMES_IN_FLIGHT]Frame_Sync;

    log_debug("Creating frame syncs (%) ...", frame_syncs.count);
    log_indent();
    for * frame_syncs {
        log_debug("(%) Creating frame sync...", it_index);
        log_indent_scope();
        it.*, _ = frame_sync_make();
    }
    log_unindent();

    defer for frame_syncs {
        frame_sync_destroy(it);
    }

    // -------------------------------------------------------
    // @Note: Main loop

    current_frame_idx := 0;
    start_time        := seconds_since_init();
    current_time      : float64;

    camera := camera_make(.{0, 4, 4}, .{0, 0, 0});

    while main_loop := true {
        swapchain := *context.vk.swapchain;
        device    := context.vk.device.handle;

        current_time = seconds_since_init();
        dt := current_time - start_time;

        // -------------------------------------------------------
        // @Note: Handle resizes

        should_resize := false;
        for Input.get_window_resizes() {
            // @Note: We don't care about other windows for now
            if it.window != app_window then continue;
            // @Note: If we are minimized, we shouldn't try to render anything
            if it.width <= 0 || it.height <= 0 then continue main_loop;

            width  := cast(u32) it.width;
            height := cast(u32) it.height;

            // @Note: Don't recreate if we already have the swapchain extent we need
            if width == window_width && height == window_height then continue;

            window_width  = width;
            window_height = height;
            should_resize = true;
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

                case .MOUSE_WHEEL;
                    camera.fov -= cast(Degrees) (it.wheel_delta / it.typical_wheel_delta) * 3;
                    Clamp(*camera.fov, 30, 100);
            }
        }

        camera_pos_add := Vector3.{};

        if Input.input_button_states[#char "W"] == .DOWN then camera_pos_add +=  camera.forward;
        if Input.input_button_states[#char "S"] == .DOWN then camera_pos_add += -camera.forward;
        if Input.input_button_states[#char "A"] == .DOWN then camera_pos_add +=  camera.right;
        if Input.input_button_states[#char "D"] == .DOWN then camera_pos_add += -camera.right;
        if Input.input_button_states[#char "Z"] == .DOWN then camera_pos_add +=  camera.up;
        if Input.input_button_states[#char "X"] == .DOWN then camera_pos_add += -camera.up;

        camera.position += camera_pos_add * camera.speed * dt;

        // -------------------------------------------------------

        in_flight_fence     := frame_syncs[current_frame_idx].in_flight_fence;
        swapchain_image_sem := frame_syncs[current_frame_idx].swapchain_image_sem;
        render_finished_sem := frame_syncs[current_frame_idx].render_finished_sem;
        cmdbuf              := gfx_cmdbufs[current_frame_idx];

        // -------------------------------------------------------
        // @Note: Get next swapchain image, recreate if out of date

        Vk.wait_for_one_fence(device, in_flight_fence);

        swapchain_image_idx : u32;
        {
            swapchain_image_idx=, result := Vk.acquire_next_image(device, swapchain.handle, semaphore = swapchain_image_sem);
            if result == .ERROR_OUT_OF_DATE_KHR {
                recreate_swapchain(window_width, window_height);
                continue main_loop;
            }
            assert(result == .SUCCESS || result == .SUBOPTIMAL_KHR, "Failed to acquire swapchain image! Result: %", result);
        }

        _ := Vk.reset_one_fence(device, in_flight_fence);

        // -------------------------------------------------------
        // @Note: Reset and begin command buffer

        _ := Vk.ResetCommandBuffer(cmdbuf, 0);
        _ := Vk.BeginCommandBuffer(cmdbuf, *(Vk.CommandBufferBeginInfo.{}));
        {
            CLEAR_VALUES :: Vk.ClearValue.[
                .{ color        = .{ _float32 = .[0.2, 0.3, 0.3, 1.0] } },
                .{ depthStencil = .{ 1.0, 0 } },
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

                #if DRAW_CMD == .CmdDraw {
                    Vk.cmd_draw(cmdbuf, VERTICES.count);
                }
                else #if DRAW_CMD == .CmdDrawInstanced {
                    Vk.cmd_draw(cmdbuf, VERTICES.count, instance_count = 25);
                }
                else #if DRAW_CMD == .CmdDrawIndexed {
                    Vk.cmd_draw_indexed(cmdbuf, INDICES.count);
                }
                else #if DRAW_CMD == .CmdDrawIndexedInstanced {
                    Vk.cmd_draw_indexed(cmdbuf, INDICES.count, instance_count = 25);
                }
            }
            Vk.CmdEndRenderPass(cmdbuf);

        }
        _ := Vk.EndCommandBuffer(cmdbuf);

        // -------------------------------------------------------
        // @Note: Update matrix uniform buffer

        aspect := cast(float) swapchain.width / swapchain.height;

        q : Quaternion;
        set_from_axis_and_angle(*q, .{0.5, 1.0, 0.5}, cast(float) (current_time * radians(90))); // @Note: Radians

        matrix_uniforms := Uniform_Matrices.{
            model = rotate(Matrix4_Identity, q) * translate(Matrix4_Identity, .{0, 0, 0}),
            view  = look_at(camera),
            proj  = perspective(radians(camera.fov), aspect, 0.1, 100.0),
        };
        mem_copy(matrix_uniform_buffers[current_frame_idx].mapped, *matrix_uniforms, size_of(Uniform_Matrices));

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
        _ := Vk.queue_one_submit(gfx_queue, submit_info, in_flight_fence);

        // -------------------------------------------------------
        // @Note: Present swapchain using present queue

        present_info := Vk.PresentInfoKHR.{
            waitSemaphoreCount = 1,
            pWaitSemaphores    = *render_finished_sem,
            swapchainCount     = 1,
            pSwapchains        = *swapchain.handle,
            pImageIndices      = *swapchain_image_idx,
        };

        result := Vk.QueuePresentKHR(present_queue, *present_info);
        if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR || should_resize {
            recreate_swapchain(window_width, window_height);
        }
        else {
            assert(result == .SUCCESS, "Failed to present swapchain image! Result: %", result);
        }

        current_frame_idx = (current_frame_idx + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    // @Note: Let the device finish any remaning operations before cleaning up resources
    _ := Vk.DeviceWaitIdle(context.vk.device.handle);
}

// -------------------------------------------------------

#placeholder asset_table;

// -------------------------------------------------------

#load "camera.jai";
#load "context.jai";
#load "utils.jai";
#load "vulkan.jai";

// -------------------------------------------------------

Vk :: #import "Vulkan-1.3" (WRAPPER = true);

#import "Enum_Array";

Input  :: #import "Input";
Window :: #import "Window_Creation";

#import "Basic";
#import "File";
#import "Math";
#import "Print_Color";
#import "Sloppy_Math";
#import "String";
#import "stb_image";

using,except(Table) HT :: #import "Hash_Table";
Hash_Table :: HT.Table;
