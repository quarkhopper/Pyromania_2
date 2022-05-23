function migrate_option_set(option_set_ser)
    -- TBD determine version
    local version = 0
    local parts = split_string(option_set_ser, DELIM.OPTION_SET)
    version = parts[2]

    -- no migrations

    return option_set_ser
end
