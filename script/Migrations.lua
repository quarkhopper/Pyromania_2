#include "Utils.lua"

function migrate_option_set(option_set_ser)
    return option_set_ser
end

function  can_migrate(option_set_ser)
    local parts = split_string(option_set_ser, DELIM.OPTION_SET)
    local version = parts[3]
    if string.find(version, "1.", 1, true) then return false end
    return true
end
