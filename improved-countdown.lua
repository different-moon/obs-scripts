obs              = obslua
countdown_type   = "target"
source_name      = ""
duration_seconds = 0
target_table     = os.date("*t")

cur_seconds      = 0
countdown_text   = ""
stop_text        = ""
last_text        = ""
activated        = false

hotkey_id        = obs.OBS_INVALID_HOTKEY_ID

-- Function to set the time text
function set_time_text()
    local seconds       = math.floor(cur_seconds % 60)
    local total_minutes = math.floor(cur_seconds / 60)
    local text          = string.format(countdown_text, total_minutes, seconds)

    if cur_seconds < 1 then
        text = stop_text
    end

    if text ~= last_text then
        local source = obs.obs_get_source_by_name(source_name)

        if source ~= nil then
            local settings = obs.obs_data_create()

            obs.obs_data_set_string(settings, "text", text)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
        end
    end

    last_text = text
end

function timer_callback()
    cur_seconds = cur_seconds - 1

    if cur_seconds < 0 then
        obs.remove_current_callback()

        cur_seconds = 0
    end

    set_time_text()
end

function activate(activating)
    if activated == activating then
        return
    end

    activated = activating

    if activating then
        cur_seconds = get_total_seconds()

        set_time_text()

        obs.timer_add(timer_callback, 1000)
    else
        obs.timer_remove(timer_callback)
    end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
    local source = obs.calldata_source(cd, "source")

    if source ~= nil then
        local name = obs.obs_source_get_name(source)

        if name == source_name then
            activate(activating)
        end
    end
end

function source_activated(cd)
    activate_signal(cd, true)
end

function source_deactivated(cd)
    activate_signal(cd, false)
end

function reset(pressed)
    if not pressed then
        return
    end

    activate(false)

    local source = obs.obs_get_source_by_name(source_name)

    if source ~= nil then
        local active = obs.obs_source_active(source)

        obs.obs_source_release(source)

        activate(active)
    end
end

function reset_button_clicked(props, p)
    reset(true)

    return false
end

function type_changed(props, prop, settings)
    local type_value = obs.obs_data_get_string(settings, "type")
    local target_property = obs.obs_properties_get(props, "target")
    local duration_property = obs.obs_properties_get(props, "duration")

    if type_value == "target" then
        obs.obs_property_set_visible(target_property, true)
        obs.obs_property_set_visible(duration_property, false)
    else
        obs.obs_property_set_visible(duration_property, true)
        obs.obs_property_set_visible(target_property, false)
    end

    return true
end

function get_total_seconds()
    if countdown_type == "target" then
        return math.max(0, os.time(target_table) - os.time())
    else
        return duration_seconds
    end
end

----------------------------------------------------------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
    local props = obs.obs_properties_create()

    local source_property = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()

    if sources ~= nil then
        for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_unversioned_id(source)

            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                local name = obs.obs_source_get_name(source)

                obs.obs_property_list_add_string(source_property, name, name)
            end
        end
    end

    obs.source_list_release(sources)

    local type_property = obs.obs_properties_add_list(props, "type", "Countdown Type", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)

    obs.obs_property_list_add_string(type_property, "Target Time", "target")
    obs.obs_property_list_add_string(type_property, "Duration", "duration")
    obs.obs_property_set_long_description(type_property, "Toggle between counting down to a specified time or for a specified duration")
    obs.obs_property_set_modified_callback(type_property, type_changed)

    local target_property = obs.obs_properties_add_text(props, "target", "Target Time (hh:MM)", obs.OBS_TEXT_DEFAULT)

    obs.obs_property_set_visible(target_property, countdown_type == "target")

    local duration_property = obs.obs_properties_add_int(props, "duration", "Duration (minutes)", 1, 100000, 1)

    obs.obs_property_set_visible(duration_property, countdown_type == "duration")

    obs.obs_properties_add_text(props, "countdown_text", "Countdown Text", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "stop_text", "Final Text", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(props, "reset_button", "Reset Timer", reset_button_clicked)

    return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
    return "Sets a text source to act as a countdown timer when the source is active.\n\nMade by Moon"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
    activate(false)

    countdown_type = obs.obs_data_get_string(settings, "type")
    source_name = obs.obs_data_get_string(settings, "source")
    countdown_text = obs.obs_data_get_string(settings, "countdown_text")
    stop_text = obs.obs_data_get_string(settings, "stop_text")

    if countdown_type == "target" then
        local time_string = obs.obs_data_get_string(settings, "target")
        local _, _, hour_string, minute_string = time_string:find("^%s*(%d?%d):(%d%d)")
        local _, _, am_pm = time_string:find("([ap]m)%s*$")

        target_table = os.date("*t")

        local hour = tonumber(hour_string) or 0
        local minute = tonumber(minute_string) or 0

        if am_pm ~= nil then
            hour = math.max(math.min(hour, 12), 1)

            if am_pm == "am" then
                if hour == 12 and minute == 0 then
                    hour = 24
                elseif hour == 12 then
                    hour = 0
                end
            elseif hour < 12 then
                hour = hour + 12
            end
        end

        if hour == 24 then
            target_table["day"] = target_table["day"] + 1
            target_table["hour"] = 0
        else
            target_table["hour"] = hour
        end

        target_table["min"] = minute
        target_table["sec"] = 0
    else
        duration_seconds = obs.obs_data_get_int(settings, "duration") * 60
    end

    reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "type", "target")
    obs.obs_data_set_default_string(settings, "target", "5:00pm")
    obs.obs_data_set_default_int(settings, "duration", 5)
    obs.obs_data_set_default_string(settings, "countdown_text", "Starting in %d:%02d")
    obs.obs_data_set_default_string(settings, "stop_text", "Starting soon!")
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
    local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)

    obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)
    -- Connect hotkey and activation/deactivation signal callbacks
    --
    -- NOTE: These particular script callbacks do not necessarily have to
    -- be disconnected, as callbacks will automatically destroy themselves
    -- if the script is unloaded.  So there's no real need to manually
    -- disconnect callbacks that are intended to last until the script is
    -- unloaded.
    local sh = obs.obs_get_signal_handler()

    obs.signal_handler_connect(sh, "source_activate", source_activated)
    obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

    hotkey_id = obs.obs_hotkey_register_frontend("reset_timer_thingy", "Reset Timer", reset)

    local hotkey_save_array = obs.obs_data_get_array(settings, "reset_hotkey")

    obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end
