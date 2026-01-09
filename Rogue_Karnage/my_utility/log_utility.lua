local log_utility = {}

-- Log levels
log_utility.LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    CRITICAL = 5
}

-- Configuration
log_utility.config = {
    enabled = true,
    level = log_utility.LEVEL.INFO, -- Minimum level to log
    show_timestamp = true,
    file_logging = true,
    max_console_entries = 100,
    max_file_entries = 500,
    log_to_console = true  -- Always log errors to console
}

-- Internal state
log_utility.entries = {}
log_utility.file_entries = {}
log_utility.init_time = get_time_since_inject()

-- Initialize logging
function log_utility.initialize(config)
    if config then
        for k, v in pairs(config) do
            log_utility.config[k] = v
        end
    end
    
    log_utility.entries = {}
    log_utility.file_entries = {}
    log_utility.init_time = get_time_since_inject()
    
    -- Create log file
    if log_utility.config.file_logging then
        log_utility.ensure_log_directory()
        local log_path = log_utility.get_log_path()
        local file = io.open(log_path, "w")
        if file then
            file:write("--- Death Trap Rogue Enhanced Script Log ---\n")
            file:write("Started at: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
            file:close()
        else
            console.print("[ERROR] Failed to create log file at: " .. log_path)
        end
    end
    
    -- Log initialization
    log_utility.info("Log system initialized")
end

-- Get formatted timestamp
function log_utility.get_timestamp()
    if log_utility.config.show_timestamp then
        local time_since_init = get_time_since_inject() - log_utility.init_time
        return string.format("[%.2fs] ", time_since_init)
    end
    return ""
end

-- Format message with level prefix
function log_utility.format_message(level, message)
    local level_prefix = ""
    if level == log_utility.LEVEL.DEBUG then
        level_prefix = "[DEBUG] "
    elseif level == log_utility.LEVEL.INFO then
        level_prefix = "[INFO] "
    elseif level == log_utility.LEVEL.WARNING then
        level_prefix = "[WARNING] "
    elseif level == log_utility.LEVEL.ERROR then
        level_prefix = "[ERROR] "
    elseif level == log_utility.LEVEL.CRITICAL then
        level_prefix = "[CRITICAL] "
    end
    
    return log_utility.get_timestamp() .. level_prefix .. message
end

-- Ensure log directory exists
function log_utility.ensure_log_directory()
    -- Attempt to create a logs directory if it doesn't exist
    local success = os.execute("mkdir logs 2>nul")
    return success
end

-- Get log file path
function log_utility.get_log_path()
    return "logs/death_trap_rogue_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
end

-- Write to log file
function log_utility.write_to_file(formatted_message)
    if not log_utility.config.file_logging then
        return
    end
    
    log_utility.ensure_log_directory()
    local log_path = log_utility.get_log_path()
    local file = io.open(log_path, "a")
    if file then
        file:write(formatted_message .. "\n")
        file:close()
    end
end

-- Log message with specified level
function log_utility.log(level, message)
    if not log_utility.config.enabled or level < log_utility.config.level then
        return
    end
    
    local formatted_message = log_utility.format_message(level, message)
    
    -- Store in memory
    table.insert(log_utility.entries, formatted_message)
    if #log_utility.entries > log_utility.config.max_console_entries then
        table.remove(log_utility.entries, 1)
    end
    
    -- Write to file
    if log_utility.config.file_logging then
        table.insert(log_utility.file_entries, formatted_message)
        if #log_utility.file_entries > log_utility.config.max_file_entries then
            table.remove(log_utility.file_entries, 1)
        end
        
        -- Write immediately to file
        log_utility.write_to_file(formatted_message)
    end
    
    -- Print to console for errors and critical messages, or if configured
    if level >= log_utility.LEVEL.ERROR or log_utility.config.log_to_console then
        console.print(formatted_message)
    end
end

-- Log debug message
function log_utility.debug(message)
    log_utility.log(log_utility.LEVEL.DEBUG, message)
end

-- Log info message
function log_utility.info(message)
    log_utility.log(log_utility.LEVEL.INFO, message)
end

-- Log warning message
function log_utility.warning(message)
    log_utility.log(log_utility.LEVEL.WARNING, message)
end

-- Log error message
function log_utility.error(message)
    log_utility.log(log_utility.LEVEL.ERROR, message)
    -- Always print errors to console regardless of configuration
    console.print(log_utility.format_message(log_utility.LEVEL.ERROR, message))
end

-- Log critical message
function log_utility.critical(message)
    log_utility.log(log_utility.LEVEL.CRITICAL, message)
    -- Always print critical errors to console regardless of configuration
    console.print(log_utility.format_message(log_utility.LEVEL.CRITICAL, message))
end

-- Execute function in protected mode and log any errors
function log_utility.protected_call(func, context)
    context = context or "unknown"
    local success, result = pcall(func)
    if not success then
        log_utility.error("Error in " .. context .. ": " .. tostring(result))
        return false, result
    end
    return true, result
end

-- Create log.txt file in parent directory for error reporting
function log_utility.create_error_log(message)
    local file = io.open("../log.txt", "a")
    if file then
        file:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
        file:close()
        return true
    end
    return false
end

return log_utility 