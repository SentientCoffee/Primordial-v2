KHR_VALIDATION_LAYER_NAME :: "VK_LAYER_KHRONOS_validation";

// -------------------------------------------------------

enumerate_device_extension_properties :: (physical_device : PhysicalDevice, layer_name : *u8) -> []ExtensionProperties #must, Result {
    extension_count : u32;
    result := EnumerateDeviceExtensionProperties(physical_device, layer_name, *extension_count, null);
    if result != .SUCCESS then return .[], result;

    extensions := NewArray(extension_count, ExtensionProperties);
    result = EnumerateDeviceExtensionProperties(physical_device, layer_name, *extension_count, extensions.data);
    return extensions, result;
}

enumerate_instance_extension_properties :: (layer_name : *u8) -> []ExtensionProperties #must, Result {
    extension_count : u32;
    result := EnumerateInstanceExtensionProperties(layer_name, *extension_count, null);
    if result != .SUCCESS then return .[], result;

    extensions := NewArray(extension_count, ExtensionProperties);
    result = EnumerateInstanceExtensionProperties(layer_name, *extension_count, extensions.data);
    return extensions, result;
}

enumerate_instance_layer_properties :: () -> []LayerProperties #must, Result {
    layer_count : u32;
    result := EnumerateInstanceLayerProperties(*layer_count, null);
    if result != .SUCCESS then return .[], result;

    layers := NewArray(layer_count, LayerProperties);
    result = EnumerateInstanceLayerProperties(*layer_count, layers.data);
    return layers, result;
}

enumerate_physical_devices :: (instance : Instance) -> []PhysicalDevice #must, Result {
    physical_device_count : u32;
    result := EnumeratePhysicalDevices(instance, *physical_device_count, null);
    if result != .SUCCESS then return .[], result;

    physical_devices := NewArray(physical_device_count, PhysicalDevice);
    result = EnumeratePhysicalDevices(instance, *physical_device_count, physical_devices.data);
    return physical_devices, result;
}

// -------------------------------------------------------

create_buffer :: (device : Device, create_info : *BufferCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Buffer, Result {
    buffer : Buffer;
    result := CreateBuffer(device, create_info, allocation_callbacks, *buffer);
    return buffer, result;
}

create_command_pool :: (device : Device, create_info : *CommandPoolCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> CommandPool, Result {
    command_pool : CommandPool;
    result := CreateCommandPool(device, create_info, allocation_callbacks, *command_pool);
    return command_pool, result;
}

create_debug_utils_messenger :: (instance : Instance, create_info : *DebugUtilsMessengerCreateInfoEXT, allocation_callbacks : *AllocationCallbacks = null) -> DebugUtilsMessengerEXT, Result {
    debug_messenger : DebugUtilsMessengerEXT;
    result := CreateDebugUtilsMessengerEXT(instance, create_info, allocation_callbacks, *debug_messenger);
    return debug_messenger, result;
}

create_device :: (physical_device : PhysicalDevice, create_info : *DeviceCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Device, Result {
    device : Device;
    result := CreateDevice(physical_device, create_info, allocation_callbacks, *device);
    return device, result;
}

create_descriptor_pool :: (device : Device, create_info : *DescriptorPoolCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> DescriptorPool, Result {
    descriptor_pool : DescriptorPool;
    result := CreateDescriptorPool(device, create_info, allocation_callbacks, *descriptor_pool);
    return descriptor_pool, result;
}

create_descriptor_set_layout :: (device : Device, create_info : *DescriptorSetLayoutCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> DescriptorSetLayout, Result {
    descriptor_set_layout : DescriptorSetLayout;
    result := CreateDescriptorSetLayout(device, create_info, allocation_callbacks, *descriptor_set_layout);
    return descriptor_set_layout, result;
}

create_fence :: (device : Device, create_info : *FenceCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Fence, Result {
    fence : Fence;
    result := CreateFence(device, create_info, allocation_callbacks, *fence);
    return fence, result;
}

create_framebuffer :: (device : Device, create_info : *FramebufferCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Framebuffer, Result {
    framebuffer : Framebuffer;
    result := CreateFramebuffer(device, create_info, allocation_callbacks, *framebuffer);
    return framebuffer, result;
}

create_one_graphics_pipeline :: (device : Device, create_info : *GraphicsPipelineCreateInfo, pipelineCache : PipelineCache = null, allocation_callbacks : *AllocationCallbacks = null) -> Pipeline, Result {
    pipeline : Pipeline;
    result := CreateGraphicsPipelines(device, pipelineCache, 1, create_info, allocation_callbacks, *pipeline);
    return pipeline, result;
}

create_graphics_pipelines :: (device : Device, create_infos : []GraphicsPipelineCreateInfo, pipelineCache : PipelineCache = null, allocation_callbacks : *AllocationCallbacks = null) -> []Pipeline, Result {
    pipelines : []Pipeline;
    result := CreateGraphicsPipelines(device, pipelineCache, cast(u32) create_infos.count, create_infos.data, allocation_callbacks, pipelines.data);
    return pipelines, result;
}

create_image :: (device : Device, create_info : *ImageCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Image, Result {
    image : Image;
    result := CreateImage(device, create_info, allocation_callbacks, *image);
    return image, result;
}

create_image_view :: (device : Device, create_info : *ImageViewCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> ImageView, Result {
    view : ImageView;
    result := CreateImageView(device, create_info, allocation_callbacks, *view);
    return view, result;
}

create_instance :: (create_info : *InstanceCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Instance, Result {
    instance : Instance;
    result := CreateInstance(create_info, allocation_callbacks, *instance);
    return instance, result;
}

create_pipeline_layout :: (device : Device, create_info : *PipelineLayoutCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> PipelineLayout, Result {
    layout : PipelineLayout;
    result := CreatePipelineLayout(device, create_info, allocation_callbacks, *layout);
    return layout, result;
}

create_render_pass :: (device : Device, create_info : *RenderPassCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> RenderPass, Result {
    render_pass : RenderPass;
    result := CreateRenderPass(device, create_info, allocation_callbacks, *render_pass);
    return render_pass, result;
}

create_sampler :: (device : Device, create_info : *SamplerCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Sampler, Result {
    sampler : Sampler;
    result := CreateSampler(device, create_info, allocation_callbacks, *sampler);
    return sampler, result;
}

create_semaphore :: (device : Device, create_info : *SemaphoreCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> Semaphore, Result {
    semaphore : Semaphore;
    result := CreateSemaphore(device, create_info, allocation_callbacks, *semaphore);
    return semaphore, result;
}

create_shader_module :: (device : Device, create_info : *ShaderModuleCreateInfo, allocation_callbacks : *AllocationCallbacks = null) -> ShaderModule, Result {
    module : ShaderModule;
    result := CreateShaderModule(device, create_info, allocation_callbacks, *module);
    return module, result;
}

create_swapchain :: (device : Device, create_info : *SwapchainCreateInfoKHR, allocation_callbacks : *AllocationCallbacks = null) -> SwapchainKHR, Result {
    swapchain : SwapchainKHR;
    result := CreateSwapchainKHR(device, create_info, allocation_callbacks, *swapchain);
    return swapchain, result;
}

create_win32_surface :: (instance : Instance, create_info : *Win32SurfaceCreateInfoKHR, allocation_callbacks : *AllocationCallbacks = null) -> SurfaceKHR, Result {
    surface : SurfaceKHR;
    result := CreateWin32SurfaceKHR(instance, create_info, allocation_callbacks, *surface);
    return surface, result;
}

// -------------------------------------------------------

get_buffer_memory_requirements :: (device : Device, buffer : Buffer) -> MemoryRequirements {
    memory_requirements : MemoryRequirements;
    GetBufferMemoryRequirements(device, buffer, *memory_requirements);
    return memory_requirements;
}

get_device_queue :: (device : Device, queueFamilyIndex : u32, queueIndex : u32) -> Queue {
    queue : Queue;
    GetDeviceQueue(device, queueFamilyIndex, queueIndex, *queue);
    return queue;
}

get_image_memory_requirements :: (device : Device, image : Image) -> MemoryRequirements {
    memory_requirements : MemoryRequirements;
    GetImageMemoryRequirements(device, image, *memory_requirements);
    return memory_requirements;
}

get_physical_device_properties :: (physical_device : PhysicalDevice) -> PhysicalDeviceProperties {
    properties : PhysicalDeviceProperties;
    GetPhysicalDeviceProperties(physical_device, *properties);
    return properties;
}

get_physical_device_features :: (physical_device : PhysicalDevice) -> PhysicalDeviceFeatures {
    features : PhysicalDeviceFeatures;
    GetPhysicalDeviceFeatures(physical_device, *features);
    return features;
}

get_physical_device_format_properties :: (physical_device : PhysicalDevice, format : Format) -> FormatProperties {
    properties : FormatProperties;
    GetPhysicalDeviceFormatProperties(physical_device, format, *properties);
    return properties;
}

get_physical_device_memory_properties :: (physical_device : PhysicalDevice) -> PhysicalDeviceMemoryProperties {
    memory_properties : PhysicalDeviceMemoryProperties;
    GetPhysicalDeviceMemoryProperties(physical_device, *memory_properties);
    return memory_properties;
}

get_physical_device_queue_family_properties :: (physical_device : PhysicalDevice) -> []QueueFamilyProperties #must {
    queue_family_count : u32;
    GetPhysicalDeviceQueueFamilyProperties(physical_device, *queue_family_count, null);

    queue_families := NewArray(queue_family_count, QueueFamilyProperties);
    GetPhysicalDeviceQueueFamilyProperties(physical_device, *queue_family_count, queue_families.data);
    return queue_families;
}

get_physical_device_surface_capabilities :: (physical_device : PhysicalDevice, surface : SurfaceKHR) -> SurfaceCapabilitiesKHR, Result {
    capabilities : SurfaceCapabilitiesKHR;
    result := GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, *capabilities);
    return capabilities, result;
}

get_physical_device_surface_formats :: (physical_device : PhysicalDevice, surface : SurfaceKHR) -> []SurfaceFormatKHR #must, Result {
    surface_format_count : u32;
    result := GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, *surface_format_count, null);
    if result != .SUCCESS then return .[], result;

    surface_formats := NewArray(surface_format_count, SurfaceFormatKHR);
    result = GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, *surface_format_count, surface_formats.data);
    return surface_formats, result;
}

get_physical_device_surface_present_modes :: (physical_device : PhysicalDevice, surface : SurfaceKHR) -> []PresentModeKHR #must, Result {
    present_mode_count : u32;
    result := GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, *present_mode_count, null);
    if result != .SUCCESS then return .[], result;

    present_modes := NewArray(present_mode_count, PresentModeKHR);
    result = GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, *present_mode_count, present_modes.data);
    return present_modes, result;
}

get_physical_device_surface_support :: (physical_device : PhysicalDevice, queue_family_index : u32, surface : SurfaceKHR) -> bool, Result {
    supported : Bool32;
    result := GetPhysicalDeviceSurfaceSupportKHR(physical_device, queue_family_index, surface, *supported);
    return supported == .TRUE, result;
}

get_swapchain_images :: (device : Device, swapchain : SwapchainKHR) -> []Image #must, Result {
    image_count : u32;
    result := GetSwapchainImagesKHR(device, swapchain, *image_count, null);
    if result != .SUCCESS then return .[], result;

    images := NewArray(image_count, Image);
    result = GetSwapchainImagesKHR(device, swapchain, *image_count, images.data);
    return images, result;
}

// -------------------------------------------------------

allocate_one_command_buffer :: (device : Device, alloc_info : *CommandBufferAllocateInfo) -> CommandBuffer, Result {
    if alloc_info.commandBufferCount > 1 {
        // If the alloc_info specified commandBufferCount > 1 then the caller should use allocate_command_buffers.
        return null, .ERROR_INITIALIZATION_FAILED;
    }

    alloc_info.commandBufferCount = 1;

    command_buffer : CommandBuffer;
    result := AllocateCommandBuffers(device, alloc_info, *command_buffer);
    return command_buffer, result;
}

allocate_command_buffers :: (device : Device, alloc_info : *CommandBufferAllocateInfo) -> []CommandBuffer #must, Result {
    command_buffers := NewArray(alloc_info.commandBufferCount, CommandBuffer);
    result := AllocateCommandBuffers(device, alloc_info, command_buffers.data);
    return command_buffers, result;
}

allocate_one_descriptor_set :: (device : Device, alloc_info : *DescriptorSetAllocateInfo) -> DescriptorSet, Result {
    if alloc_info.descriptorSetCount > 1 {
        // If the alloc_info specified descriptorSetCount > 1 then the caller should use allocate_descriptor_sets.
        return null, .ERROR_INITIALIZATION_FAILED;
    }

    alloc_info.descriptorSetCount = 1;

    descriptor_set : DescriptorSet;
    result := AllocateDescriptorSets(device, alloc_info, allocation_callbacks, *descriptor_set);
    return descriptor_set, result;
}

allocate_descriptor_sets :: (device : Device, alloc_info : *DescriptorSetAllocateInfo) -> []DescriptorSet #must, Result {
    descriptor_sets := NewArray(alloc_info.descriptorSetCount, DescriptorSet);
    result := AllocateDescriptorSets(device, alloc_info, descriptor_sets.data);
    return descriptor_sets, result;
}

allocate_memory :: (device : Device, alloc_info : *MemoryAllocateInfo, allocation_callbacks : *AllocationCallbacks = null) -> DeviceMemory, Result {
    memory : DeviceMemory;
    result := AllocateMemory(device, alloc_info, allocation_callbacks, *memory);
    return memory, result;
}

free_memory :: inline (device : Device, memory : DeviceMemory, allocation_callbacks : *AllocationCallbacks = null) {
    FreeMemory(device, memory, allocation_callbacks);
}

// -------------------------------------------------------

cmd_bind_descriptor_sets :: inline (command_buffer : CommandBuffer, bind_point : PipelineBindPoint, layout : PipelineLayout, descriptor_sets : []DescriptorSet, first_set : u32 = 0, dynamic_offsets : []u32 = .[]) {
    CmdBindDescriptorSets(command_buffer, bind_point, layout, first_set, cast(u32) descriptor_sets.count, descriptor_sets.data, cast(u32) dynamic_offsets.count, dynamic_offsets.data);
}

cmd_bind_one_descriptor_set :: inline (command_buffer : CommandBuffer, bind_point : PipelineBindPoint, layout : PipelineLayout, descriptor_set : DescriptorSet, dynamic_offset : *u32 = null) {
    CmdBindDescriptorSets(command_buffer, bind_point, layout, 0, 1, *descriptor_set, cast(u32) (ifx dynamic_offset then 1 else 0), dynamic_offset);
}

cmd_bind_index_buffer :: inline (command_buffer : CommandBuffer, index_buffer : Buffer, offset : DeviceSize = 0, index_type : IndexType = .UINT32) {
    CmdBindIndexBuffer(command_buffer, index_buffer, offset, index_type);
}

cmd_bind_one_vertex_buffer :: inline (command_buffer : CommandBuffer, vertex_buffer : Buffer, offset : DeviceSize = 0) {
    CmdBindVertexBuffers(command_buffer, 0, 1, *vertex_buffer, *offset);
}

cmd_bind_vertex_buffers :: inline (command_buffer : CommandBuffer, vertex_buffers : []Buffer, offsets : []DeviceSize, first_binding : u32 = 0) {
    assert(vertex_buffers.count == offsets.count);
    CmdBindVertexBuffers(command_buffer, first_binding, cast(u32) vertex_buffers.count, vertex_buffers.data, offsets.data);
}

cmd_copy_buffer :: inline (command_buffer : CommandBuffer, src_buffer : Buffer, dst_buffer : Buffer, regions : []BufferCopy) {
    CmdCopyBuffer(command_buffer, src_buffer, dst_buffer, cast(u32) regions.count, regions.data);
}

cmd_copy_buffer_to_image :: inline (command_buffer : CommandBuffer, src_buffer : Buffer, dst_image : Image, dst_image_layout : ImageLayout, regions : []BufferImageCopy) {
    CmdCopyBufferToImage(command_buffer, src_buffer, dst_image, dst_image_layout, cast(u32) regions.count, regions.data);
}

cmd_draw :: inline (command_buffer : CommandBuffer, vertex_count : u32, instance_count : u32 = 1, first_vertex : u32 = 0, first_instance : u32 = 0) {
    CmdDraw(command_buffer, vertex_count, instance_count, first_vertex, first_instance);
}

cmd_draw_indexed :: inline (command_buffer : CommandBuffer, index_count : u32, instance_count : u32 = 1, first_index : u32 = 0, vertex_offset : s32 = 0, first_instance : u32 = 0) {
    CmdDrawIndexed(command_buffer, index_count, instance_count, first_index, vertex_offset, first_instance);
}

cmd_pipeline_barrier :: inline (command_buffer : CommandBuffer, src_stage_mask : PipelineStageFlags, dst_stage_mask : PipelineStageFlags, dependency_flags : DependencyFlags = 0, memory_barriers : []MemoryBarrier = .[], buffer_memory_barriers : []BufferMemoryBarrier = .[], image_memory_barriers : []ImageMemoryBarrier = .[]) {
    CmdPipelineBarrier(command_buffer, src_stage_mask, dst_stage_mask, dependency_flags, cast(u32) memory_barriers.count, memory_barriers.data, cast(u32) buffer_memory_barriers.count, buffer_memory_barriers.data, cast(u32) image_memory_barriers.count, image_memory_barriers.data);
}

cmd_set_one_scissor :: inline (command_buffer : CommandBuffer, scissor : Rect2D) {
    CmdSetScissor(command_buffer, 0, 1, *scissor);
}

cmd_set_scissor :: inline (command_buffer : CommandBuffer, scissors : []Rect2D, first_scissor : u32 = 0) {
    CmdSetScissor(command_buffer, first_scissor, cast(u32) scissors.count, scissors.data);
}

cmd_set_one_viewport :: inline (command_buffer : CommandBuffer, viewport : Viewport) {
    CmdSetViewport(command_buffer, 0, 1, *viewport);
}

cmd_set_viewport :: inline (command_buffer : CommandBuffer, viewports : []Viewport, first_viewport : u32 = 0) {
    CmdSetViewport(command_buffer, first_viewport, cast(u32) viewports.count, viewports.data);
}

// -------------------------------------------------------

reset_one_fence :: (device : Device, fence : Fence) -> Result {
    return ResetFences(device, 1, *fence);
}

reset_fences :: (device : Device, fences : []Fence) -> Result {
    return ResetFences(device, cast(u32) fences.count, fences.data);
}

wait_for_one_fence :: (device : Device, fence : Fence, timeout := U64_MAX) -> Result {
    return WaitForFences(device, 1, *fence, .TRUE, timeout);
}

wait_for_fences :: (device : Device, fences : []Fence, waitAll := Bool32.TRUE, timeout := U64_MAX) -> Result {
    return WaitForFences(device, cast(u32) fences.count, fences.data, waitAll, timeout);
}

// -------------------------------------------------------

queue_one_submit :: (queue : Queue, submit_info : SubmitInfo, fence : Fence = null) -> Result {
    return QueueSubmit(queue, 1, *submit_info, fence);
}

queue_submit :: (queue : Queue, submit_infos : []SubmitInfo, fence : Fence = null) -> Result {
    return QueueSubmit(queue, cast(u32) submit_infos.count, submit_infos.data, fence);
}

// -------------------------------------------------------

acquire_next_image :: (device : Device, swapchain : SwapchainKHR, timeout := U64_MAX, semaphore : Semaphore = null, fence : Fence = null) -> u32, Result {
    image_index : u32;
    result := AcquireNextImageKHR(device,swapchain, timeout,semaphore, fence, *image_index);
    return image_index, result;
}

map_memory :: (device : Device, memory : DeviceMemory, offset : DeviceSize, size : DeviceSize, flags : MemoryMapFlags = 0) -> *void, Result {
    mapped : *void;
    result := MapMemory(device, memory, offset, size, flags, *mapped);
    return mapped, result;
}

unmap_memory :: inline (device : Device, memory : DeviceMemory) {
    UnmapMemory(device, memory);
}

update_descriptor_sets :: inline (device : Device, writes : []WriteDescriptorSet = .[], copies : []CopyDescriptorSet = .[]) {
    UpdateDescriptorSets(device, cast(u32) writes.count, writes.data, cast(u32) copies.count, copies.data);
}

// -------------------------------------------------------

using #import "Vulkan-1.3";

#scope_file

#import "Basic";
#import "Math";
