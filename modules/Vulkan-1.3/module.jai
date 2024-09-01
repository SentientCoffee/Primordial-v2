#module_parameters (WRAPPER := true);

NULL_HANDLE :: null;

Bool32 :: enum u32 {
    FALSE :: 0;
    TRUE  :: 1;
}

WHOLE_SIZE : u64 : 0xffff_ffff_ffff_ffff;  // ~0ULL
UUID_SIZE  : u32 : 16;
LUID_SIZE  : u32 : 8;

LOD_CLAMP_NONE : float32 : 1000.0;

SUBPASS_EXTERNAL      : u32 : 0xffff_ffff;  // ~0U
ATTACHMENT_UNUSED     : u32 : 0xffff_ffff;  // ~0U
SHADER_UNUSED_KHR     : u32 : 0xffff_ffff;  // ~0U
QUEUE_FAMILY_IGNORED  : u32 : 0xffff_ffff;  // ~0U
QUEUE_FAMILY_EXTERNAL : u32 : 0xffff_fffe;  // ~1U

REMAINING_ARRAY_LAYERS  : u32 : 0xffff_ffff;  // ~0U
REMAINING_MIP_LEVELS    : u32 : 0xffff_ffff;  // ~0U
REMAINING_3D_SLICES_EXT : u32 : 0xffff_ffff;  // ~0U

MAX_DESCRIPTION_SIZE          : u32 : 256;
MAX_DEVICE_GROUP_SIZE         : u32 : 32;
MAX_DRIVER_NAME_SIZE          : u32 : 256;
MAX_DRIVER_INFO_SIZE          : u32 : 256;
MAX_EXTENSION_NAME_SIZE       : u32 : 256;
MAX_MEMORY_HEAPS              : u32 : 16;
MAX_MEMORY_TYPES              : u32 : 32;
MAX_PHYSICAL_DEVICE_NAME_SIZE : u32 : 256;

MAKE_API_VERSION :: inline (variant: u32, major: u32, minor: u32, patch: u32) -> u32 {
    return (variant << 29) | (major << 22) | (minor << 12) | patch;
}

API_VERSION_VARIANT :: (version: u32) -> u32 { return  version >> 29;          }
API_VERSION_MAJOR   :: (version: u32) -> u32 { return (version >> 22) & 0x7f;  }
API_VERSION_MINOR   :: (version: u32) -> u32 { return (version >> 12) & 0x3ff; }
API_VERSION_PATCH   :: (version: u32) -> u32 { return  version        & 0xfff; }

API_VERSION_1_0 :: #run MAKE_API_VERSION(0, 1, 0, 0);
API_VERSION_1_1 :: #run MAKE_API_VERSION(0, 1, 1, 0);
API_VERSION_1_2 :: #run MAKE_API_VERSION(0, 1, 2, 0);
API_VERSION_1_3 :: #run MAKE_API_VERSION(0, 1, 3, 0);

HEADER_VERSION_COMPLETE :: #run MAKE_API_VERSION(0, 1, 3, HEADER_VERSION);

// DEPRECATED: This define is deprecated. MAKE_API_VERSION should be used instead.
MAKE_VERSION :: inline (major: u32, minor: u32, patch: u32) -> u32
#deprecated "MAKE_API_VERSION should be used instead." {
    return MAKE_API_VERSION(0, major, minor, patch);
}

// DEPRECATED: This define is deprecated. API_VERSION_MAJOR should be used instead.
VERSION_MAJOR :: API_VERSION_MAJOR;

// DEPRECATED: This define is deprecated. API_VERSION_MINOR should be used instead.
VERSION_MINOR :: API_VERSION_MINOR;

// DEPRECATED: This define is deprecated. API_VERSION_PATCH should be used instead.
VERSION_PATCH :: API_VERSION_PATCH;

// -------------------------------------------

#if OS == .WINDOWS {
    wchar_t :: s16;
    #load "generated_windows.jai";
    #load "loader_windows.jai";
}
else #if OS == .LINUX {
    #load "generated_linux.jai";
    #load "loader_linux.jai";
}

#if WRAPPER {
    #load "wrapper.jai";
}
