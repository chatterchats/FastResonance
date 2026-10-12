-- Resonance Probe v2 (development tool, never shipped)
-- Logs what the Fast Resonance rewrite needs to know about Coil ability
-- presentations. Run with Fast Resonance disabled so rates are vanilla.
--   STATE  every state begin/end inside a Coil ability state machine (the timeline)
--   PROPS  numeric settings of each node class the first time it runs in each machine
--   PLAY   sequence states: sequence, camera rate, bound actors (or why none was found)
--   SEQ    animations each played sequence drives, including sub-sequences
--   MONT   every montage change on any character while a sequence plays
--   NODE   SMN_PlagueBroadcaster / SMN_Resonate values on CDO, templates, instances

-- Coil ability state machines (every SM_*.uasset under Abilities/Humanoid/Coil,
-- plus the enemy-turn plague broadcast presentation).
local MACHINES = {}
for _, sm in ipairs({
    "SM_Scream", "SM_TenacityHeal", "SM_Tenacity", "SM_Miasma", "SM_Resonate",
    "SM_Coil_DeathExplosion", "SM_LifeBeyondDeath", "SM_SharedSuffering_Redirect",
    "SM_SharedSuffering", "SM_MeleeStrike", "SM_PlagueBroadcaster", "SM_PlagueSurge",
    "SM_Bind_AttackerRelease", "SM_Bind", "SM_Devour", "SM_Passive_PlagueStackGain",
    "SM_Cloak_Tutorial", "SM_Cloak", "SM_Decloak_OnCondition",
    "SM_AbilityPresentation_PlagueBroadcast",
}) do MACHINES[sm] = true end

-- Every state/node class those machines reference (from their packages).
local STATE_CLASSES = {
    "Cinematics/Blueprints/Stage/StateMachine/SMstate_PlayChoreographedSequence",
    "Cinematics/AbilitySequences/SMState_PlaySequence",
    "Cinematics/AbilitySequences/SMState_EndCinematic",
    "Cinematics/AbilitySequences/SMstate_AbilityPresentationStyle",
    "Cinematics/Blueprints/Stage/StateMachine/SMstate_SimpleDelay",
    "Cinematics/Blueprints/Stage/StateMachine/SMstate_SetCommonCameraStance",
    "Cinematics/Blueprints/Stage/StateMachine/SMstate_SetRegisteredCameraTargets",
    "Cinematics/Blueprints/Stage/StateMachine/SMstate_SetCameraMode",
    "Cinematics/Blueprints/Stage/StateMachine/SMstate_ResetPuckToLocation",
    "Cinematics/Blueprints/Stage/StateMachine/SMState_SourceTeam",
    "Cinematics/Blueprints/Stage/StateMachine/SMState_UnitStance_LookAt",
    "Cinematics/Blueprints/Stage/StateMachine/SMState_SendGameplayEvent",
    "Cinematics/Blueprints/Stage/StateMachine/SMState_GroundMove",
    "Cinematics/Blueprints/TurnDirectorStateMachines/States/SMState_EnemyTurnStoryNode_StartAbilitiesSimultaneously",
    "Core/Animation/SMState_WaitForStance",
    "Abilities/Humanoid/Coil/PlagueBroadcaster/SMN_PlagueBroadcaster",
    "Abilities/Humanoid/Coil/Captain/Resonate/SMN_Resonate",
    "Abilities/Humanoid/Coil/Shared/SMN_CheckPlagueStacks",
    "FX/Blueprints/Abilities/Coil/Seer/SMN_FX_Coil_Seer_BindBroken",
    "FX/Blueprints/Abilities/Coil/Guardian/SMN_FX_Coil_Guardian_SharedSuffering_TargetHit",
    "FX/Blueprints/Abilities/Coil/Guardian/SMN_FX_Coil_Guardian_SharedSuffering_GuardianReceived_Dmg",
}

-- Sequence states: where to find the sequence actor and the bound characters.
local PLAY = {
    SMstate_PlayChoreographedSequence_C = {actor = "LevelSequenceActor", bound = {"Bound Actors"}},
    SMState_PlaySequence_C = {actor = "SequenceActor", bound = {"BindActors", "SourceActor", "Target Actor"}},
}

local NODE_CLASSES = {
    SMN_PlagueBroadcaster_C = "/Game/Game/Abilities/Humanoid/Coil/PlagueBroadcaster/SMN_PlagueBroadcaster",
    SMN_Resonate_C = "/Game/Game/Abilities/Humanoid/Coil/Captain/Resonate/SMN_Resonate",
}

local function log(fmt, ...)
    print(string.format("[ResonanceProbe] " .. fmt .. "\n", ...))
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

local function try(fn)
    local ok, value = pcall(fn)
    if ok then return value end
end

local function valid(obj)
    return obj ~= nil and try(function() return obj:IsValid() end) == true
end

local function name(obj)
    return valid(obj) and (try(function() return obj:GetFullName() end) or "?") or "nil"
end

local function class_name(obj)
    return try(function() return obj:GetClass():GetFName():ToString() end) or "?"
end

-- FName/FString/number/bool -> printable string
local function str(v)
    if type(v) ~= "userdata" then return tostring(v) end
    return try(function() return v:ToString() end) or tostring(v)
end

local function each(arr, fn)
    pcall(function()
        arr:ForEach(function(i, elem) fn(elem:get(), i) end)
    end)
end

local seen = {}
local function once(prefix, line)
    if seen[line] then return end
    seen[line] = true
    log("%s %s", prefix, line)
end

-- "...SMRunner_9.SM_SharedSuffering_C_0.SMstate_SimpleDelay_C_1" -> "SM_SharedSuffering_C_0"
local function coil_machine(full)
    for instance, sm in full:gmatch("%.((SM_[%w_]+)_C_%d+)%.") do
        if MACHINES[sm] then return instance end
    end
end

-- Numeric/bool properties declared on the object's own Blueprint class.
local function props(obj)
    local values = {}
    pcall(function()
        obj:GetClass():ForEachProperty(function(prop)
            local kind = try(function() return prop:GetClass():GetFName():ToString() end) or ""
            if kind:find("Float") or kind:find("Double") or kind:find("Int")
                or kind:find("Bool") or kind:find("Byte") then
                local pname = prop:GetFName():ToString()
                values[#values + 1] = pname .. "=" .. str(try(function() return obj[pname] end))
            end
        end)
    end)
    return table.concat(values, " | ")
end

--------------------------------------------------------------------------------
-- Sequences and node defaults
--------------------------------------------------------------------------------

local function dump_sequence(seq, depth)
    local key = name(seq)
    if not valid(seq) or seen["seq:" .. key] or depth > 4 then return end
    seen["seq:" .. key] = true
    local pad = string.rep("  ", depth)
    log("SEQ %s%s", pad, key)
    local movie = try(function() return seq.MovieScene end)
    if not valid(movie) then log("SEQ %s  (no MovieScene)", pad); return end

    local function track(t, binding)
        local class = class_name(t)
        if class:find("SkeletalAnimation", 1, true) then
            each(t.AnimationSections, function(section)
                local p = section.Params
                log("SEQ %s  ANIM | binding=%s | %s | slot=%s", pad, binding,
                    name(p.Animation), str(try(function() return p.SlotName end)))
            end)
        elseif class:find("SubTrack", 1, true) or class:find("CinematicShot", 1, true) then
            each(t.Sections, function(section)
                dump_sequence(try(function() return section.SubSequence end), depth + 1)
            end)
        end
        return class
    end

    each(movie.ObjectBindings, function(binding)
        local bname = str(try(function() return binding.BindingName end))
        local classes = {}
        each(binding.Tracks, function(t) classes[#classes + 1] = track(t, bname) end)
        log("SEQ %s  binding %s | %s", pad, bname, table.concat(classes, ", "))
    end)
    local classes = {}
    each(movie.Tracks, function(t) classes[#classes + 1] = track(t, "<root>") end)
    log("SEQ %s  root | %s", pad, table.concat(classes, ", "))
end

local function flags(obj)
    if try(function() return obj:HasAnyFlags(0x10) end) then return "CDO" end
    if try(function() return obj:HasAnyFlags(0x20) end) then return "template" end
    return "instance"
end

local function dump_nodes()
    for short, path in pairs(NODE_CLASSES) do
        local cdo = StaticFindObject(path .. ".Default__" .. short)
        if valid(cdo) then once("NODE", string.format("CDO | %s | %s", short, props(cdo))) end
        for _, obj in pairs(FindAllOf(short) or {}) do
            once("NODE", string.format("%s | %s | %s", flags(obj), name(obj), props(obj)))
        end
        -- FindAllOf skipped the TEMPLATE_ archetypes last run; ask for them directly.
        local class = StaticFindObject(path .. "." .. short)
        if valid(class) then
            local ok, found = pcall(FindObjects, 0, class, nil, 0x20, 0, false)
            if not ok then
                once("NODE", "FindObjects failed | " .. tostring(found))
            else
                local n = 0
                for _, obj in pairs(found or {}) do
                    n = n + 1
                    once("NODE", string.format("%s | %s | %s", flags(obj), name(obj), props(obj)))
                end
                once("NODE", string.format("archetypes of %s found: %d", short, n))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Sequence states
--------------------------------------------------------------------------------

local plays = {} -- state full name -> record

local function montage_line(anim, montage)
    local segments = {}
    each(montage.SlotAnimTracks, function(track)
        local slot = str(try(function() return track.SlotName end))
        each(track.AnimTrack.AnimSegments, function(seg)
            segments[#segments + 1] = string.format("%s@%s", name(seg.AnimReference), slot)
        end)
    end)
    return string.format("%s | rate=%s | segments: %s",
        name(montage):find("/Engine/Transient", 1, true) and "dynamic" or name(montage),
        str(try(function() return anim:Montage_GetEffectivePlayRate(montage) end)),
        table.concat(segments, ", "))
end

local function sample(record)
    if plays[record.key] ~= record or not valid(record.state) then return end
    for _, anim in ipairs(record.anims) do
        if valid(anim) then
            local montage = try(function() return anim:GetCurrentActiveMontage() end)
            local mname = valid(montage) and name(montage) or "none"
            local akey = name(anim)
            if record.montages[akey] ~= mname then
                record.montages[akey] = mname
                if mname ~= "none" then
                    local owner = try(function() return anim:GetOwningActor() end)
                    log("MONT %s | %s (%s) | %s", record.id, class_name(owner),
                        record.bound[name(owner)] and "bound" or "not bound", montage_line(anim, montage))
                end
            end
        end
    end
    record.samples = record.samples + 1
    if record.samples < 300 then later(100, "sample", function() sample(record) end) end
end

local count = 0

local function report(record, final)
    local state, spec = record.state, record.spec
    local actor = try(function() return state[spec.actor] end)
    local seq = valid(actor) and try(function() return actor:GetSequence() end)
    if not valid(seq) then seq = try(function() return state:GetPlayingLevelSequence() end) end
    if not valid(seq) then
        if final then
            log("PLAY %s | no sequence found | actor=%s | %s", record.machine, name(actor), record.key)
            plays[record.key] = nil
        end
        return
    end

    count = count + 1
    record.id = "#" .. count
    local bound = {}
    for _, prop in ipairs(spec.bound) do
        local value = try(function() return state[prop] end)
        local full = try(function() return value:GetFullName() end) -- nil for arrays
        if full then
            bound[#bound + 1] = full
        elseif value ~= nil then
            each(value, function(v) bound[#bound + 1] = name(v) end)
        end
    end
    for _, b in ipairs(bound) do record.bound[b] = true end
    local player = valid(actor) and try(function() return actor:GetSequencePlayer() end)
    log("PLAY %s | %s | %s | sequence=%s | camera rate=%s | bound: %s", record.id, record.machine,
        class_name(state), name(seq),
        str(valid(player) and try(function() return player:GetPlayRate() end)),
        table.concat(bound, ", "))
    dump_sequence(seq, 0)

    for _, anim in pairs(FindAllOf("AnimInstance") or {}) do
        if valid(anim) and valid(try(function() return anim:GetOwningActor() end)) then
            record.anims[#record.anims + 1] = anim
        end
    end
    sample(record)
end

local function on_play(state, key, machine, spec)
    if plays[key] then return end
    local record = {key = key, state = state, spec = spec, machine = machine,
                    bound = {}, anims = {}, montages = {}, samples = 0}
    plays[key] = record
    local delays = {0, 50, 150, 400, 1000}
    for i, delay in ipairs(delays) do
        later(delay, "play", function()
            if plays[key] == record and not record.id then report(record, i == #delays) end
        end)
    end
end

--------------------------------------------------------------------------------
-- State timeline
--------------------------------------------------------------------------------

local function on_state(state, phase)
    local key = name(state)
    local machine = coil_machine(key)
    if not machine then return end
    local class = class_name(state)
    local short = key:match("([^%.]+)$")
    log("STATE %s | %s | %s", phase, machine, short)
    if phase == "begin" then
        once("PROPS", string.format("%s | %s | %s", machine:gsub("_C_%d+$", ""), class, props(state)))
        if PLAY[class] then on_play(state, key, machine, PLAY[class]) end
        if class:find("^SMN_") then dump_nodes() end
    else
        plays[key] = nil
    end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

local CLASS_PATHS = {}
for _, path in ipairs(STATE_CLASSES) do
    local short = path:match("[^/]+$")
    CLASS_PATHS["/Game/Game/" .. path .. "." .. short .. "_C"] = true
end

local installed = {}

local function install_hooks()
    for class in pairs(CLASS_PATHS) do
        for fn, phase in pairs({OnStateBegin = "begin", OnStateEnd = "end"}) do
            local path = class .. ":" .. fn
            if not installed[path] and valid(StaticFindObject(path)) then
                RegisterHook(path, safe(path, function(ctx) on_state(ctx:get(), phase) end))
                installed[path] = true
                log("Hooked %s", path)
            end
        end
    end
end

-- State classes load with their abilities; hook them when they do.
NotifyOnNewObject("/Script/CoreUObject.Class", function(class)
    local path = name(class):match("^%S+%s+(.+)$")
    if path and CLASS_PATHS[path] then
        for _, delay in ipairs({0, 500, 2000}) do later(delay, "install hooks", install_hooks) end
    end
end)

-- Catch-all: every state machine the game creates, Coil or not, so unknown
-- presentations (like whatever runs when Miasma goes off) show up by name.
NotifyOnNewObject("/Script/SMSystem.SMInstance", function(sm)
    later(0, "machine", function()
        local full = name(sm)
        if full == "nil" or full:find("Default__", 1, true) then return end
        local outer = full:match("([^%.:]+)%.[^%.]+$") or "?"
        log("SM new | %s | owner=%s", class_name(sm), outer)
    end)
end)

log("v2 loaded | %d state classes | %d machines", #STATE_CLASSES, (function()
    local n = 0
    for _ in pairs(MACHINES) do n = n + 1 end
    return n
end)())
later(0, "install hooks", install_hooks)
