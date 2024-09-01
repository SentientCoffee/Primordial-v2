Enum_Array :: struct(Enum: Type, T: Type)
#modify {
    ti := cast(*Type_Info) Enum;
    if ti.type != .ENUM then return false, "Enum_Array needs an enum as the first struct argument.";

    ti_e := cast(*Type_Info_Enum) ti;
    min, max := enum_range_given_info(ti_e);
    if (max - min) != (ti_e.values.count - 1) then return false, "Enum_Array cannot use a sparse enum.";

    return true;
}{
    count :: #run -> s64 {
        min, max := enum_range(Enum);
        return max - min + 1;
    }

    array: [count]T;
}

// -------------------------------------------------------
// @Note: These are just convenience functions if you don't want to write enum_array[Enum.Value]
//        (because the enum name might be super long and unary '.' enum dereferencing doesn't work)

get :: (enum_array: Enum_Array, en: enum_array.Enum) -> value: enum_array.T {
    i := index_from_enum_value(en);
    return enum_array.array[i];
}

set :: (enum_array: *Enum_Array, en: enum_array.Enum, value: enum_array.T) {
    i := index_from_enum_value(en);
    enum_array.array[i] = value;
}

// -------------------------------------------------------

// @Note: The only reason this works is because enums are integer-adjacent, meaning that operator *[] will accept them as arguments.
//        However, unary enum dereferencing (i.e. '.Value' instead of 'Enum.Value') will not work, because they are technically not supported.
operator *[] :: (enum_array: Enum_Array, en: enum_array.Enum) -> *enum_array.T {
    i := index_from_enum_value(en);
    return *enum_array.array[i];
}

for_expansion :: (enum_array: *Enum_Array, body: Code, flags: For_Flags) #expand {
    REVERSE :: (flags & .REVERSE) != 0;
    POINTER :: (flags & .POINTER) != 0;

    for <=REVERSE *=POINTER value, idx : enum_array.array {
        `it := value;
        `it_index := enum_value_from_index(enum_array.Enum, idx);

        #insert body;
    }
}

// -------------------------------------------------------

#scope_file

index_from_enum_value :: (e: $Enum) -> int
#modify {
    ti := cast(*Type_Info) Enum;
    if ti.type != .ENUM then return false, "Given input to convert from is not an enum.";
    return true;
}{
    min, max := enum_range(Enum);
    assert(cast(s64) e >= min);
    assert(cast(s64) e <= max);

    return (cast(s64) e) - min;
}

enum_value_from_index :: ($Enum: Type, i: int) -> Enum
#modify {
    ti := cast(*Type_Info) Enum;
    if ti.type != .ENUM then return false, "Given type to convert to is not an enum.";
    return true;
}{
    min, max := enum_range(Enum);
    assert(i + min >= min);
    assert(i + min <= max);

    return cast(Enum) (i + min);
}

#import "Basic";
