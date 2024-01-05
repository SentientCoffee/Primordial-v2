setup_context :: (highest_logger_level := Logger_Level.Info, logger_flags := Logger_Flags.Level | .Terminal_Color) #expand {
    context.assertion_failed = assert_proc;
    context.logger           = console_logger_proc;
    context.logger_data      = *logger_data;

    set_highest_logger_level(highest_logger_level);
    set_logger_flags(logger_flags);
}

set_highest_logger_level :: inline (level : Logger_Level) {
    if      level >= .Info  then context.log_level = .NORMAL;
    else if level >= .Debug then context.log_level = .VERBOSE;
    else                         context.log_level = .VERY_VERBOSE;

    highest_logger_level = level;
}

set_logger_flags :: inline (flags : Logger_Flags) {
    logger_flags = flags;
}

// -------------------------------------------------------

Logger_Flags :: enum_flags u32 {
    Level;
    Terminal_Color;
}

Logger_Level :: enum u32 {
    None;
    Trace;
    Debug;
    Info;
    Warning;
    Error;
    Fatal;
}

Logger_Section :: enum {
    None;
    Assert;
    Vulkan;
}

log_trace :: (fmt : string, args : ..Any, loc := #caller_location, section := Logger_Section.None) {
    if highest_logger_level > .Trace then return;

    data := cast(*Logger_Data) context.logger_data;
    data.level     = .Trace;
    data.proc_name = get_procedure_name();
    data.section   = section;

    log(fmt, ..args, loc = loc);
} @PrintLike

log_debug :: (fmt : string, args : ..Any, loc := #caller_location, section := Logger_Section.None) {
    if highest_logger_level > .Debug then return;

    data := cast(*Logger_Data) context.logger_data;
    data.level     = .Debug;
    data.proc_name = get_procedure_name();
    data.section   = section;

    log(fmt, ..args, loc = loc);
} @PrintLike

log_info :: (fmt : string, args : ..Any, loc := #caller_location, section := Logger_Section.None) {
    if highest_logger_level > .Info then return;

    data := cast(*Logger_Data) context.logger_data;
    data.level     = .Info;
    data.proc_name = get_procedure_name();
    data.section   = section;

    log(fmt, ..args, loc = loc);
} @PrintLike

log_warning :: (fmt : string, args : ..Any, loc := #caller_location, section := Logger_Section.None) {
    if highest_logger_level > .Warning then return;

    data := cast(*Logger_Data) context.logger_data;
    data.level     = .Warning;
    data.proc_name = get_procedure_name();
    data.section   = section;

    log(fmt, ..args, loc = loc);
} @PrintLike

log_error :: (fmt : string, args : ..Any, loc := #caller_location, section := Logger_Section.None) {
    if highest_logger_level > .Error then return;

    data := cast(*Logger_Data) context.logger_data;
    data.level     = .Error;
    data.proc_name = get_procedure_name();
    data.section   = section;

    log(fmt, ..args, loc = loc);
} @PrintLike

log_fatal :: (fmt : string, args : ..Any, loc := #caller_location, section := Logger_Section.None) {
    if highest_logger_level > .Fatal then return;

    data := cast(*Logger_Data) context.logger_data;
    data.level     = .Fatal;
    data.proc_name = get_procedure_name();
    data.section   = section;

    log(fmt, ..args, loc = loc);
} @PrintLike

// -------------------------------------------------------

log_indent :: () {
    indent_level += 1;
}

log_unindent :: () {
    indent_level = max(0, indent_level - 1);
}

log_indent_scope :: () #expand {
    log_indent();
    `defer log_unindent();
}

// -------------------------------------------------------

vk_debug_callback :: (
    message_severity   : Vk.DebugUtilsMessageSeverityFlagsEXT,
    message_type_flags : Vk.DebugUtilsMessageTypeFlagsEXT,
    callback_data      : *Vk.DebugUtilsMessengerCallbackDataEXT,
    user_data          : *void
) -> Vk.Bool32 #c_call {
    message_id_number := callback_data.messageIdNumber;
    message_id_name   := to_string(callback_data.pMessageIdName);
    message           := to_string(callback_data.pMessage);

    if message_id_name == "Loader Message" then return .FALSE;

    ctx := cast(*Context) user_data;
    push_context ctx {
        log_msg := tprint("% (0x%): %", message_id_name, FormatInt.{value = message_id_number, base = 16}, message);
        if      message_severity & .ERROR_EXT   then log_error  (log_msg, section = .Vulkan);
        else if message_severity & .WARNING_EXT then log_warning(log_msg, section = .Vulkan);
        else                                         log_trace  (log_msg, section = .Vulkan);
    }

    return .FALSE;
}

// -------------------------------------------------------

#scope_file

highest_logger_level := Logger_Level.Info;
logger_flags         := Logger_Flags.Level | .Terminal_Color;

logger_data := Logger_Data.{};
Logger_Data :: struct {
    level     : Logger_Level;
    section   : Logger_Section;
    proc_name : string;
}

indent       := "|";
indent_level := 0;

// @Note: Kind of arbitrary?
largest_reported_location_count := 25;
largest_section_name_count :: #run -> s64 {
    level_names   := enum_names(Logger_Level);
    section_names := enum_names(Logger_Section);

    max_name_count := 0;
    for level_names {
        if max_name_count < it.count then max_name_count = it.count;
    }
    for section_names {
        if max_name_count < it.count then max_name_count = it.count;
    }

    return max_name_count;
}

get_procedure_name :: () -> string #expand {
    return context.stack_trace.next.info.name;
}

console_logger_proc :: (msg : string, logger_data : *void, info : Log_Info) {
    message := msg;
    flags   := logger_flags;
    data    := cast(*Logger_Data) logger_data;

    // @Note: Strip trailing newlines from the message
    while message[message.count-1] == #char "\n" {
        message.count -= 1;
    }

    builder := string_builder_make();
    {
        section_name : string;
        if      data.section != .None                     then section_name = tprint("%", data.section);
        else if info.section && info.section.name         then section_name = info.section.name;
        else if (flags & .Level) && (data.level != .None) then section_name = tprint("%", data.level);
        else if info.common_flags & .ERROR                then section_name = "External Error";
        else if info.common_flags & .WARNING              then section_name = "External Warning";
        else                                                   section_name = "External Log";

        string_builder_append(*builder, #char "[");
        to_append := largest_section_name_count - section_name.count;
        for 1..to_append  string_builder_append(*builder, " ");
        string_builder_print(*builder, "%]", section_name);
    }

    {
        reported_proc := data.proc_name;
        if (flags & .Level) && (data.level == .Fatal) || !reported_proc {
            reported_proc = info.location.fully_pathed_filename;
        }

        reported_location := tprint("%:%:%", reported_proc, info.location.line_number, info.location.character_number);
        if largest_reported_location_count < reported_location.count then largest_reported_location_count = reported_location.count;

        string_builder_append(*builder, #char "[");
        to_append := largest_reported_location_count - reported_location.count;
        for 1..to_append  string_builder_append(*builder, " ");
        string_builder_print(*builder, "%] ", reported_location);
    }

    if flags & .Terminal_Color {
        color := Console_Color.HI_WHITE;
        if flags & .Level {
            if #complete data.level == {
                case .Trace;   // @Note: Do nothing.

                case .Debug;   color = .CYAN;
                case .Info;    color = .HI_GREEN;
                case .Warning; color = .HI_YELLOW;

                case .Error;   #through;
                case .Fatal;   color = .HI_RED;

                case .None;
                    if info.common_flags {
                        if      info.common_flags & .ERROR   then color = .HI_RED;
                        else if info.common_flags & .WARNING then color = .HI_YELLOW;
                    }
            }
        }
        with_console_color(color, write_builder(*builder));
        if flags & .Level && data.level == .Fatal {
            with_console_color(color, write_strings(message, "\n"));
        }
        else {
            for 1..indent_level {
                write_strings(indent, " ");
            }
            write_strings(message, "\n");
        }
    }
    else {
        write_builder(*builder);
        for 1..indent_level {
            write_strings(indent, " ");
        }
        write_strings(message, "\n");
    }

    // @Note: Reset logger data so we don't get weird bugs if we log from somewhere outside of the app
    data.* = Logger_Data.{};
}

// -------------------------------------------------------

assert_proc :: (loc : Source_Code_Location, message : string) -> bool {
    sb := string_builder_make();
    string_builder_print(*sb, "%\n", message);

    node := context.stack_trace;

    // @Note: This is just to make the stack trace easier to read :)
    max_proc_name_count := 0;
    max_loc_\     count := 0;
    while node {
        defer node = node.next;

        if node.call_depth > context.stack_trace.call_depth - 2 then continue;  // @Note: Skip `assert_proc` and `assert`
        if node.call_depth == 0 then break;                                     // @Note: Skip unknown proc before `main`

        proc_name := "<unknown>";
        file_name := "<unknown file>";
        if node.info {
            file_name = node.info.location.fully_pathed_filename;
            proc_name = node.info.name;
        }

        reported_loc_count := file_name.count + tprint("%", node.line_number).count + 1; // @Note: +1 for the colon in between

        if max_proc_name_count < proc_name.count    then max_proc_name_count = proc_name.count;
        if max_loc_count       < reported_loc_count then max_loc_count       = reported_loc_count;
    }

    string_builder_append(*sb, "Call stack:\n");
    node = context.stack_trace;
    while node {
        defer node = node.next;

        if node.call_depth > context.stack_trace.call_depth - 2 then continue;  // @Note: Skip `assert_proc` and `assert`
        if node.call_depth == 0 then break;                                     // @Note: Skip unknown proc before `main`

        proc_name := "<unknown>";
        file_name := "<unknown file>";
        if node.info {
            file_name = node.info.location.fully_pathed_filename;
            proc_name = node.info.name;
        }

        string_builder_print(*sb, "    [%] %", node.call_depth, proc_name);
        to_append := max_proc_name_count - proc_name.count + 1; // @Note: +1 to get a trailing space
        for 1..to_append  string_builder_append(*sb, #char " ");

        reported_loc_count := file_name.count + tprint("%", node.line_number).count + 1; // @Note: +1 for the colon in between
        string_builder_print(*sb, "@ %:%", file_name, node.line_number);
        to_append = max_loc_count - reported_loc_count + 1;                              // @Note: +1 to get a trailing space
        for 1..to_append  string_builder_append(*sb, #char " ");

        string_builder_print(*sb, "(hash 0x%)\n", FormatInt.{value = node.hash, base = 16, comma_string = "_", digits_per_comma = 4});
    }

    log_fatal(builder_to_string(*sb), loc = loc, section = .Assert);

    result := Debug.show_assert_dialog(loc, message);
    if result == {
        case .Ignore; // @Note: Do nothing for now.
        case .Abort; abort();
        case .Debug;
            if attach_to_debugger() {
                debug_break();
            }
            else {
                log_fatal("No debugger attached. Aborting...");
                abort();
            }
    };

    return false;  // We're handling the program debug_break ourselves.
}

abort :: () {
    #if OS == .WINDOWS {
        Win32.TerminateProcess(Win32.GetCurrentProcess(), xx Debug.Exit_Code.Assert);
    }
    else #if OS == .LINUX {
        exit(2);
    }
}

attach_to_debugger :: () -> bool {
    if Debug.is_debugger_present() return true;

    #if OS == .WINDOWS {
        system_directory: [1024]u16;
        Win32.GetSystemDirectoryW(system_directory.data, system_directory.count - 1);

        remedy_cmd := tprint("remedybg.exe attach-to-process-by-id %1 --jit-event-handle %1", Win32.GetCurrentProcessId());

        sSi : Win32.STARTUPINFOW;
        sPi : Win32.PROCESS_INFORMATION;
        defer if sPi.hThread  then Win32.CloseHandle(sPi.hThread);
        defer if sPi.hProcess then Win32.CloseHandle(sPi.hProcess);

        b := Win32.CreateProcessW(null, utf8_to_wide(remedy_cmd), null, null, 0, 0, null, null, *sSi, *sPi);
        if !b {
            // @Note: fallback to vsjit if remedy fails
            vsjit_cmd := tprint("%\\vsjitdebugger.exe -p %", wide_to_utf8(system_directory.data), Win32.GetCurrentProcessId());
            b = Win32.CreateProcessW(null, utf8_to_wide(vsjit_cmd), null, null, 0, 0, null, null, *sSi, *sPi);
            if !b then return false;

            Win32.WaitForSingleObject(sPi.hProcess, Win32.INFINITE);

            dwExitCode : u32;
            Win32.GetExitCodeProcess(sPi.hProcess, *dwExitCode);
            if dwExitCode != 0 then return false; // @Note: If exit code is zero, a debugger was selected
        }

        for 0..5*60 {
            if Win32.IsDebuggerPresent() != .FALSE then return true;
            Win32.Sleep(200);
        }
    }

    return false;
}

// -------------------------------------------------------

Debug :: #import "Debug"; // @Todo: remove this
