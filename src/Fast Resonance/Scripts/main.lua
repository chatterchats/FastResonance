-- Fast Resonance
-- Speeds up Coil ability presentations without speeding up combat as a whole.
-- Each ability runs a cinematic state machine (SM_*). Inside the enabled ones:
--   * sequences play faster: the camera and the body animation are both in the
--     sequence, so its play rate covers both;
--   * fixed holds (SimpleDelay) and effect build/travel times are shortened on
--     the state machine's node templates, which the game copies for every cast.
local VERSION = "1.1.0"
local Config = require("MXM")

-- MXM toggle -> the ability state machines it covers.
local ABILITIES = {
    resonance_transfer_enabled = {"SM_PlagueBroadcaster", "SM_Resonate", "SM_AbilityPresentation_PlagueBroadcast"},
    shared_suffering_enabled = {"SM_SharedSuffering", "SM_SharedSuffering_Redirect"},
    unnatural_resilience_enabled = {"SM_Tenacity"},
    tenacity_heal_enabled = {"SM_TenacityHeal"},
    miasma_enabled = {"SM_Miasma"},
    plague_surge_enabled = {"SM_PlagueSurge", "SM_Passive_PlagueStackGain"},
    scream_enabled = {"SM_Scream"},
    devour_enabled = {"SM_Devour"},
    bind_enabled = {"SM_Bind", "SM_Bind_AttackerRelease"},
    cloak_enabled = {"SM_Cloak", "SM_Cloak_Tutorial", "SM_ReactionCloak", "SM_Decloak_OnCondition"},
    death_explosion_enabled = {"SM_Coil_DeathExplosion"},
    life_beyond_death_enabled = {"SM_LifeBeyondDeath"},
    melee_strike_enabled = {"SM_MeleeStrike"},
}
local TOGGLE = {} -- "SM_Tenacity" -> "unnatural_resilience_enabled"
for key, machines in pairs(ABILITIES) do
    for _, machine in ipairs(machines) do TOGGLE[machine] = key end
end

-- Sequence state class -> property holding its LevelSequenceActor.
local SEQUENCE_STATES = {
    ["/Game/Game/Cinematics/Blueprints/Stage/StateMachine/SMstate_PlayChoreographedSequence.SMstate_PlayChoreographedSequence_C"] = "LevelSequenceActor",
    ["/Game/Game/Cinematics/AbilitySequences/SMState_PlaySequence.SMState_PlaySequence_C"] = "SequenceActor",
}

-- Node class -> property -> "time" (divided by speed) or "rate" (multiplied).
local BRIDGE = {
    ["BridgeBuildTime"] = "time",
    ["DelayToTransferAfterBridgeBuild"] = "time",
    ["BridgeBuildTimeDelayForAudio"] = "time",
    ["Distance Covered PreSecond"] = "rate",
}
local NODES = {
    ["/Game/Game/Cinematics/Blueprints/Stage/StateMachine/SMstate_SimpleDelay.SMstate_SimpleDelay_C"] = {["Delay Time"] = "time"},
    ["/Game/Game/Abilities/Humanoid/Coil/PlagueBroadcaster/SMN_PlagueBroadcaster.SMN_PlagueBroadcaster_C"] = BRIDGE,
    ["/Game/Game/Abilities/Humanoid/Coil/Captain/Resonate/SMN_Resonate.SMN_Resonate_C"] = BRIDGE,
    ["/Game/Game/FX/Blueprints/Abilities/Coil/Guardian/SMN_FX_Coil_Guardian_SharedSuffering_TargetHit.SMN_FX_Coil_Guardian_SharedSuffering_TargetHit_C"] = {["Distance Covered PreSecond"] = "rate"},
}

local speed, enabled = 4.0, {}

local function read_settings()
    speed = math.min(8.0, math.max(0.25, tonumber(Config.Get("speed", 4.0)) or 4.0))
    for key in pairs(ABILITIES) do enabled[key] = Config.Get(key, true) == true end
end

-- Speed for a state machine: 1.0 when its ability is off or it isn't a Coil ability.
local function factor(machine)
    local key = TOGGLE[machine]
    return key and enabled[key] and speed or 1.0
end

local function log(fmt, ...)
    print(string.format("[FastResonance] " .. fmt .. "\n", ...))
end

local function safe(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then log("ERROR | %s | %s", label, tostring(err)) end
    end
end

local function later(ms, label, fn)
    ExecuteInGameThreadWithDelay(MakeActionHandle(), ms, safe(label, fn))
end

local function valid(obj)
    if not obj then return false end
    local ok, result = pcall(function() return obj:IsValid() end)
    return ok and result == true
end

local function full_name(obj)
    return valid(obj) and obj:GetFullName() or nil
end

-- "...SMRunner_9.SM_SharedSuffering_C_0.SMstate_SimpleDelay_C_1" -> "SM_SharedSuffering"
local function machine_of(name)
    for machine in name:gmatch("%.(SM_[%w_]+)_C_%d+%.") do
        if TOGGLE[machine] then return machine end
    end
end

--------------------------------------------------------------------------------
-- Node templates
--------------------------------------------------------------------------------

local vanilla = {} -- template full name -> property -> original value
local patched = {} -- machine -> true once its templates have been set

local function patch_templates()
    local count = 0
    for class_path, props in pairs(NODES) do
        local class = StaticFindObject(class_path)
        if valid(class) then
            -- RF_ArchetypeObject: the CDO and the per-machine TEMPLATE_ copies.
            for _, template in pairs(FindObjects(0, class, nil, 0x20, 0, false) or {}) do
                local name = full_name(template) or ""
                local machine = name:match("%.(SM_[%w_]+)_C:TEMPLATE_")
                if machine and TOGGLE[machine] then
                    local f = factor(machine)
                    vanilla[name] = vanilla[name] or {}
                    for prop, kind in pairs(props) do
                        local original = vanilla[name][prop]
                        if original == nil then
                            original = template[prop]
                            vanilla[name][prop] = original
                        end
                        if type(original) == "number" then
                            template[prop] = kind == "time" and original / f or original * f
                            count = count + 1
                        end
                    end
                    patched[machine] = true
                end
            end
        end
    end
    if count > 0 then log("Node timings set | %d values | x%s", count, speed) end
end

-- Ability classes load in bursts; set templates once the burst has settled.
local queued = false
local function queue_patch()
    if queued then return end
    queued = true
    later(500, "templates", function()
        queued = false
        patch_templates()
    end)
end

--------------------------------------------------------------------------------
-- Sequences
--------------------------------------------------------------------------------

local pending = {} -- sequence state full name -> record

local function sequence_begin(state, actor_prop)
    local key = full_name(state)
    local machine = key and machine_of(key)
    if not machine then return end
    if not patched[machine] then -- class loaded late: fixes the next cast
        patched[machine] = true
        patch_templates()
    end
    local f = factor(machine)
    if f == 1.0 then return end
    local record = {}
    pending[key] = record
    -- The actor and player can be assigned just after the state begins.
    for _, delay in ipairs({0, 50, 150, 400, 1000}) do
        later(delay, "sequence", function()
            if pending[key] ~= record or record.player or not valid(state) then return end
            local actor = state[actor_prop]
            local player = valid(actor) and actor:GetSequencePlayer()
            if not valid(player) or not player:IsPlaying() then return end
            player:SetPlayRate(f)
            record.player = player
            local sequence = actor:GetSequence()
            log("%s | x%s | %s", machine, f, valid(sequence) and sequence:GetFName():ToString() or "?")
        end)
    end
end

local function sequence_end(state)
    local key = full_name(state)
    local record = key and pending[key]
    if not record then return end
    pending[key] = nil
    -- Sequence actors can be reused; never leave one running fast.
    if valid(record.player) then record.player:SetPlayRate(1.0) end
end

--------------------------------------------------------------------------------
-- Hooks and settings
--------------------------------------------------------------------------------

local installed = {}

local function install_hooks()
    for class, actor_prop in pairs(SEQUENCE_STATES) do
        local hooks = {
            [class .. ":OnStateBegin"] = function(ctx) sequence_begin(ctx:get(), actor_prop) end,
            [class .. ":OnStateEnd"] = function(ctx) sequence_end(ctx:get()) end,
        }
        for path, callback in pairs(hooks) do
            if not installed[path] and valid(StaticFindObject(path)) then
                RegisterHook(path, safe(path, callback))
                installed[path] = true
                log("Hooked %s", path)
            end
        end
    end
end

-- Sequence states and ability state machines load with missions: hook the
-- states, and set the new machine's node templates once it has finished loading.
NotifyOnNewObject("/Script/CoreUObject.Class", function(class)
    local short = class:GetFName():ToString()
    local machine = short:match("^(SM_[%w_]+)_C$")
    if machine and TOGGLE[machine] then
        queue_patch()
    elseif short == "SMstate_PlayChoreographedSequence_C" or short == "SMState_PlaySequence_C" then
        for _, delay in ipairs({0, 500, 2000}) do later(delay, "install hooks", install_hooks) end
    end
end)

Config.OnChange(function()
    read_settings()
    log("Settings changed | x%s", speed)
    patch_templates()
end)

read_settings()
log("v%s loaded | x%s", VERSION, speed)
later(0, "startup", function()
    install_hooks()
    patch_templates()
end)
