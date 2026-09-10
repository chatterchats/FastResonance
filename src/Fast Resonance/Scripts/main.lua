-- Fast Resonance v1.0.2
-- Star Wars Zero Company / UE4SS
--
-- Speeds selected Coil Resonance presentations while preserving their normal
-- state-machine completion paths.
--
-- Configurable through Mixamoo Mod Config Manager (optional):
--   * Resonance Transfer: enable + multiplier
--   * Shared Suffering:   enable + multiplier
--
-- Without MXM Config Manager installed, the bundled MXM client falls back to
-- the schema defaults (enabled, 4.0x).
--
-- Resonance Transfer covers:
--   * Coil_PlagueTransfer_Surge body animation
--   * LS_AG_PlagueTransfer_Surge_* camera choreography
--   * brk_combat_i_do_surge_* recipient reaction
--
-- Shared Suffering covers:
--   * A_1HMelee_Guardian_SharedSuffering body animation
--   * LS_AG_SharedSuffering camera choreography
--   * its context-gated generic Confirm choreography
--   * its exact 2.0-second SMstate_SimpleDelay end hold
--
-- Scope is deliberately narrow: no global animation, MovieScene, or Delay
-- acceleration is used.

local Settings = require("MXM")
local Targets = require("targets")

local TAG = "[FastResonance]"
local VERSION = "1.0.2"

local MIN_SPEED = 0.25
local MAX_SPEED = 8.0

local RETRY_MS = {0, 2, 5, 10, 15, 20, 30, 45, 60, 90, 130, 180, 250}
local PRIMARY_ANIM_TOKEN = "ABP_BR_Humanoid_Base_C"
local CHOREO_CLASS_SHORT = "SMstate_PlayChoreographedSequence_C"

local target_montages = {}
local successfully_applied = {}
local choreo_class = nil
local choreo_hooks_registered = false

local function log(fmt, ...)
    print(string.format(TAG .. " " .. fmt .. "\n", ...))
end

local function debug_log(fmt, ...)
    -- Detailed user-facing diagnostics were removed from MXM in v0.12.
    -- Keep this helper quiet so existing narrow debug call sites need no churn.
end

-- UE4SS RegisterHook and TArray:ForEach callbacks provide
-- RemoteUnrealParam/LocalUnrealParam wrappers. Only those documented callback
-- boundaries should ever be dereferenced with :get().
--
-- Do NOT probe arbitrary userdata for a "get" method: UObject.__index returns
-- a non-nil placeholder for missing members in current UE4SS builds, and
-- attempting to call that placeholder can produce "TrivialObject" errors.
local function param_get(param)
    if param == nil then return nil end

    local ok, value = pcall(function()
        return param:get()
    end)

    return ok and value or nil
end

local function valid(obj)
    if not obj then return false end

    local ok, result = pcall(function()
        return obj:IsValid()
    end)

    return ok and result
end

local function full_name(obj)
    if not valid(obj) then
        return "<invalid>"
    end

    local ok, name = pcall(function()
        return obj:GetFullName()
    end)

    return (ok and name) or "<unknown>"
end

local function get_prop(obj, name)
    if obj == nil then return nil end

    local ok, value = pcall(function()
        return obj[name]
    end)

    return ok and value or nil
end

local function safe_len(arr)
    if arr == nil then return 0 end

    local ok, n = pcall(function()
        return #arr
    end)
    if ok then return n end

    local ok2, n2 = pcall(function()
        return arr:GetArrayNum()
    end)

    return ok2 and n2 or 0
end

local function array_for_each(arr, cb)
    if arr == nil then return false end

    local ok = pcall(function()
        arr:ForEach(function(index, elem)
            cb(index, param_get(elem))
        end)
    end)

    if ok then return true end

    local n = safe_len(arr)
    if n <= 0 then return false end

    for i = 0, n - 1 do
        local ok_elem, elem = pcall(function()
            return arr[i]
        end)

        if ok_elem then
            cb(i, elem)
        end
    end

    return true
end

local function clamp_speed(value)
    local n = tonumber(value) or 1.0

    if n < MIN_SPEED then n = MIN_SPEED end
    if n > MAX_SPEED then n = MAX_SPEED end

    return n
end

local function set_param(param, value)
    if param == nil then return false end

    local ok = pcall(function()
        param:set(value)
    end)
    if ok then return true end

    ok = pcall(function()
        param:Set(value)
    end)
    if ok then return true end

    return false
end

local function desired_speed(target)
    -- Return vanilla 1x when this ability family is disabled. This also resets
    -- reusable LevelSequencePlayers that may retain an earlier faster value.
    if target.enabled_key
        and Settings.Get(target.enabled_key, true) ~= true then
        return 1.0
    end

    return clamp_speed(Settings.Get(target.speed_key, 4.0))
end

local function matching_target(name, list, context_name)
    for _, target in ipairs(list) do
        if name:find(target.token, 1, true) then
            if target.context_token then
                if context_name
                    and context_name:find(target.context_token, 1, true) then
                    return target
                end
            else
                return target
            end
        end
    end

    return nil
end

----------------------------------------------------------------------------
-- Recipient montage acceleration
----------------------------------------------------------------------------

local function inspect_target_montage(montage)
    if not valid(montage) then
        return nil
    end

    local tracks = get_prop(montage, "SlotAnimTracks")
    if safe_len(tracks) <= 0 then
        return nil
    end

    local result = nil

    array_for_each(tracks, function(_, slot_track)
        if result then return end

        local anim_track = get_prop(slot_track, "AnimTrack")
        local segments = get_prop(anim_track, "AnimSegments")

        array_for_each(segments, function(_, segment)
            if result then return end

            local anim_ref = get_prop(segment, "AnimReference")
            if not valid(anim_ref) then return end

            local asset_name = full_name(anim_ref)
            local target = matching_target(asset_name, Targets.montages)

            if target then
                result = {
                    target = target,
                    asset_name = asset_name,
                }
            end
        end)
    end)

    return result
end

local function for_each_primary_anim_instance(cb)
    local ok, objects = pcall(FindAllOf, "AnimInstance")
    if not ok or objects == nil then
        return
    end

    local function consider(obj)
            if not valid(obj) then return end

        local name = full_name(obj)
        if name:find(PRIMARY_ANIM_TOKEN, 1, true) then
            cb(obj, name)
        end
    end

    if type(objects) == "table" then
        for _, obj in pairs(objects) do
            consider(obj)
        end
        return
    end

    local ok_each = pcall(function()
        objects:ForEach(function(_, elem)
            consider(param_get(elem))
        end)
    end)

    if not ok_each then
        consider(objects)
    end
end

local function verify_montage_rate(anim, montage)
    local raw = nil
    local effective = nil
    local position = nil

    pcall(function()
        raw = anim:Montage_GetPlayRate(montage)
    end)

    pcall(function()
        effective = anim:Montage_GetEffectivePlayRate(montage)
    end)

    pcall(function()
        position = anim:Montage_GetPosition(montage)
    end)

    return raw, effective, position
end

local function apply_to_live_montage(montage, info)
    if not valid(montage) then
        return false
    end

    local montage_name = full_name(montage)
    local target = info.target
    local speed = desired_speed(target)
    local applied = false

    for_each_primary_anim_instance(function(anim, owner_name)
        if applied then return end

        local ok, active = pcall(function()
            return anim:GetCurrentActiveMontage()
        end)


        if not ok or not valid(active) then
            return
        end

        if full_name(active) ~= montage_name then
            return
        end

        local before_raw, before_effective, before_position =
            verify_montage_rate(anim, montage)

        local set_ok, set_err = pcall(function()
            anim:Montage_SetPlayRate(montage, speed)
        end)

        if not set_ok then
            log(
                "ERROR: Montage_SetPlayRate failed | kind=%s | owner=%s | montage=%s | %s",
                target.kind,
                owner_name,
                montage_name,
                tostring(set_err)
            )
            return
        end

        local after_raw, after_effective, after_position =
            verify_montage_rate(anim, montage)

        applied = true
        successfully_applied[montage_name] = true

        log(
            "LIVE RATE APPLIED | kind=%s | configured=%sx | raw %s -> %s | effective %s -> %s | owner=%s | montage=%s",
            target.kind,
            tostring(speed),
            tostring(before_raw),
            tostring(after_raw),
            tostring(before_effective),
            tostring(after_effective),
            owner_name,
            montage_name
        )

        debug_log(
            "position %s -> %s | embedded=%s",
            tostring(before_position),
            tostring(after_position),
            info.asset_name
        )
    end)

    return applied
end

local function detect_and_schedule_montage(montage)
    if not valid(montage) then return end

    local montage_name = full_name(montage)

    for _, delay_ms in ipairs(RETRY_MS) do
        ExecuteWithDelay(delay_ms, function()
            if not valid(montage) then return end
            if successfully_applied[montage_name] then return end

            local info = target_montages[montage_name]

            if not info then
                info = inspect_target_montage(montage)

                if info then
                    target_montages[montage_name] = info

                    debug_log(
                        "TARGET MONTAGE | kind=%s | montage=%s | embedded=%s",
                        info.target.kind,
                        montage_name,
                        info.asset_name
                    )
                end
            end

            if info then
                apply_to_live_montage(montage, info)
            end
        end)
    end
end

NotifyOnNewObject(
    "/Script/Engine.AnimMontage",
    detect_and_schedule_montage
)

-- Catch package montages already resident at startup.
do
    local ok, objects = pcall(FindAllOf, "AnimMontage")

    if ok and objects ~= nil then
        if type(objects) == "table" then
            for _, montage in pairs(objects) do
                if valid(montage) then
                    detect_and_schedule_montage(montage)
                end
            end
        else
            pcall(function()
                objects:ForEach(function(_, elem)
                    local montage = param_get(elem)
                    if valid(montage) then
                        detect_and_schedule_montage(montage)
                    end
                end)
            end)
        end
    end
end

----------------------------------------------------------------------------
-- Resonance camera Level Sequence acceleration
----------------------------------------------------------------------------

local function get_sequence_player(actor)
    if not valid(actor) then
        return nil
    end

    local player = nil

    pcall(function()
        player = actor:GetSequencePlayer()
    end)


    if valid(player) then
        return player
    end

    for _, prop in ipairs({"SequencePlayer", "Sequence Player"}) do
        local candidate = get_prop(actor, prop)
        if valid(candidate) then
            return candidate
        end
    end

    return nil
end

local function identify_sequence_target(state)
    if not valid(state) then
        return nil, nil
    end

    local sequence = get_prop(state, "Level Sequence")
    if not valid(sequence) then
        return nil, nil
    end

    local sequence_name = full_name(sequence)
    local state_name = full_name(state)
    local target = matching_target(
        sequence_name,
        Targets.level_sequences,
        state_name
    )

    return target, sequence_name
end

local function apply_camera_rate(state, reason)
    if not valid(state) then
        return false
    end

    local target, sequence_name = identify_sequence_target(state)
    if not target then
        return false
    end

    local actor = get_prop(state, "LevelSequenceActor")
    if not valid(actor) then
        return false
    end

    local player = get_sequence_player(actor)
    if not valid(player) then
        return false
    end

    local speed = desired_speed(target)
    local before = nil

    pcall(function()
        before = player:GetPlayRate()
    end)

    -- Always set the desired rate, including 1x when disabled, so a reusable
    -- player cannot retain an earlier Fast Resonance value.
    local ok, err = pcall(function()
        player:SetPlayRate(speed)
    end)

    if not ok then
        log(
            "ERROR: camera SetPlayRate failed | kind=%s | reason=%s | sequence=%s | %s",
            target.kind,
            tostring(reason),
            tostring(sequence_name),
            tostring(err)
        )
        return false
    end

    local after = nil
    pcall(function()
        after = player:GetPlayRate()
    end)

    log(
        "CAMERA RATE APPLIED | kind=%s | configured=%sx | play_rate %s -> %s | sequence=%s",
        target.kind,
        tostring(speed),
        tostring(before),
        tostring(after),
        sequence_name
    )

    debug_log(
        "camera reason=%s | player=%s",
        tostring(reason),
        full_name(player)
    )

    return true
end

local function register_choreo_hooks()
    if choreo_hooks_registered or not valid(choreo_class) then
        return
    end

    local wanted = {
        ["Sequence Play"] = true,
        ["Play Sequence"] = true,
        ["OnStateBegin"] = true,
    }

    pcall(function()
        choreo_class:ForEachFunction(function(fn)
            if not valid(fn) then return end

            local name = full_name(fn)
            local short = name:match(":([^:]+)$")

            if not wanted[short] then
                return
            end

            local path = name:gsub("^Function%s+", "")

            local ok, err = pcall(function()
                RegisterHook(
                    path,
                    function(Context, ...)
                        local state = param_get(Context)
                        if not valid(state) then return end

                        if apply_camera_rate(state, short .. " PRE") then
                            return
                        end

                        -- Depending on entry point, the sequence actor/player
                        -- may be assigned a few milliseconds later.
                        for _, delay_ms in ipairs({0, 5, 15, 30, 60}) do
                            ExecuteWithDelay(delay_ms, function()
                                if valid(state) then
                                    apply_camera_rate(
                                        state,
                                        short .. " +" .. tostring(delay_ms) .. "ms"
                                    )
                                end
                            end)
                        end
                    end
                )
            end)

            if ok then
                debug_log("CHOREO HOOK READY | %s", path)
            else
                log(
                    "ERROR: CHOREO HOOK FAILED | %s | %s",
                    path,
                    tostring(err)
                )
            end
        end)
    end)

    choreo_hooks_registered = true
end

local function discover_choreo_class()
    if valid(choreo_class) then
        register_choreo_hooks()
        return
    end

    local ok, cls = pcall(function()
        return FindObject("Class", CHOREO_CLASS_SHORT)
    end)

    if ok and valid(cls) then
        choreo_class = cls
        register_choreo_hooks()
    end
end

discover_choreo_class()

NotifyOnNewObject("/Script/CoreUObject.Class", function(cls)
    if valid(choreo_class) or not valid(cls) then
        return
    end

    local name = full_name(cls)

    if name:find(CHOREO_CLASS_SHORT, 1, true) then
        choreo_class = cls
        register_choreo_hooks()
    end
end)

----------------------------------------------------------------------------
-- Shared Suffering exact post-sequence delay acceleration
--
-- Probe v1 established:
--
--   22:11:53.6255  SMstate_SimpleDelay begins
--   22:11:53.6255  Delay(duration=2.0)
--   22:11:55.6370  transition leaves SMstate_SimpleDelay
--
-- This is the remaining visible Shared Suffering hold.
--
-- Do NOT touch:
--   * the 10.0-second SMState_WaitForStance timeout (it normally exits early)
--   * the 6.0-second SM_SharedSuffering_C shutdown/cleanup delay
--   * any other Kismet Delay in the game
----------------------------------------------------------------------------

local SHARED_SUFFERING_CONTEXT_TOKEN = "SM_SharedSuffering_C_"
local SHARED_SUFFERING_SIMPLE_DELAY_TOKEN = "SMstate_SimpleDelay_C"
local SHARED_SUFFERING_DELAY_SECONDS = 2.0
local DELAY_EPSILON = 0.01

local function is_shared_suffering_simple_delay(world)
    if not valid(world) then return false end

    local name = full_name(world)

    return name:find(SHARED_SUFFERING_CONTEXT_TOKEN, 1, true) ~= nil
        and name:find(SHARED_SUFFERING_SIMPLE_DELAY_TOKEN, 1, true) ~= nil
end

local function register_shared_suffering_delay_hook()
    local ok, err = pcall(function()
        RegisterHook(
            "/Script/Engine.KismetSystemLibrary:Delay",
            function(Context, WorldContextObject, Duration, ...)
                if Settings.Get("shared_suffering_enabled", true) ~= true then
                    return
                end

                local world = param_get(WorldContextObject)
                if not is_shared_suffering_simple_delay(world) then
                    return
                end

                local original = tonumber(param_get(Duration))
                if original == nil then
                    return
                end

                if math.abs(original - SHARED_SUFFERING_DELAY_SECONDS) > DELAY_EPSILON then
                    debug_log(
                        "Shared Suffering SimpleDelay ignored | duration=%s | context=%s",
                        tostring(original),
                        full_name(world)
                    )
                    return
                end

                local speed = clamp_speed(
                    Settings.Get("shared_suffering_speed", 4.0)
                )

                local replacement = original / speed

                if not set_param(Duration, replacement) then
                    log(
                        "ERROR: failed to change Shared Suffering end delay | %ss -> %ss | context=%s",
                        tostring(original),
                        tostring(replacement),
                        full_name(world)
                    )
                    return
                end

                log(
                    "SHARED SUFFERING DELAY APPLIED | configured=%sx | %ss -> %ss | context=%s",
                    tostring(speed),
                    tostring(original),
                    tostring(replacement),
                    full_name(world)
                )
            end
        )
    end)

    if not ok then
        log(
            "ERROR: Shared Suffering Delay hook failed | %s",
            tostring(err)
        )
    else
        debug_log(
            "Shared Suffering exact Delay hook ready"
        )
    end
end

register_shared_suffering_delay_hook()

----------------------------------------------------------------------------
-- MXM live settings
----------------------------------------------------------------------------

Settings.OnChange(function(_, changed)
    log(
        "Settings changed | %s | applies to the next matching presentation",
        table.concat(changed, ", ")
    )
end)

local function setting_summary()
    local function state(key)
        return Settings.Get(key, true) == true and "on" or "off"
    end

    return string.format(
        "resonance-transfer=%s@%sx | shared-suffering=%s@%sx",
        state("resonance_transfer_enabled"),
        tostring(clamp_speed(Settings.Get("resonance_transfer_speed", 4.0))),
        state("shared_suffering_enabled"),
        tostring(clamp_speed(Settings.Get("shared_suffering_speed", 4.0)))
    )
end

log(
    "Loaded v%s | MXM=%s | %s",
    VERSION,
    Settings.IsAvailable() and "available" or "defaults-only",
    setting_summary()
)
