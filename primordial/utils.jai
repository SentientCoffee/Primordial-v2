offset_of :: ($T : Type, $member : string) -> s64 #expand #modify {
    ti := cast(*Type_Info) T;
    if ti.type != .STRUCT then return false, "offset_of only works on struct types.";
    tis := cast(*Type_Info_Struct) ti;

    found_member := false;
    for tis.members {
        if it.name == member {
            found_member = true;
        }
    }

    if !found_member then return false, tprint("\"%\" is not a member of %.", member, T);
    return true;
}{
    #insert -> string {
        sb : String_Builder;
        string_builder_print(*sb, "dummy : % = ---;\n", T);
        string_builder_print(*sb, "return cast(s64) (cast(*void) (*dummy.%) - cast(*void) *dummy);\n", member);
        return builder_to_string(*sb);
    }
}

bit_cast :: ($T : Type, value : $V) -> T #expand {
    #assert size_of(V) == size_of(T) "bit_cast only works with types of the same runtime size.";
    return (cast(*T) (*value)).*;
}


advance_string :: (s : *string, count : s64) #expand {
    s.data  += count;
    s.count -= count;
}

// -------------------------------------------------------

range :: ($upper : $T) -> [upper]T #expand {
    return range(0, upper);
}

range :: ($lower : T, $upper : $T) -> [upper - lower]T #expand {
    #if T != s8 && T != s16 && T != s32 && T != s64 && T != u8 && T != u16 && T != u32 && T != u64 {
        #assert false "range only accepts integers.";
    }

    count :: upper - lower;
    #insert -> string {
        sb : String_Builder;
        string_builder_print(*sb, "return %.[", T);
        for 1..count {
            string_builder_print(*sb, "%", it + lower - 1);
            if it < count then string_builder_append(*sb, ", ");
        }
        string_builder_append(*sb, "];\n");
        return builder_to_string(*sb);
    }
}

// -------------------------------------------------------

string_builder_make :: inline () -> String_Builder {
    b : String_Builder;
    init_string_builder(*b);
    return b;
}

mem_copy :: memcpy;

string_builder_init   :: init_string_builder;
string_builder_print  :: print_to_builder;
string_builder_append :: append;