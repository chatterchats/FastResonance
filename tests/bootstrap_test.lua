-- Production wiring under a controllable game-thread scheduler.
-- luajit tests/bootstrap_test.lua "src/Fast Resonance/Scripts"
local scripts = assert(arg[1])
package.path = scripts .. "/?.lua;" .. package.path
local hooks, notifications, lifecycle, queue, cancelled = {}, {}, {}, {}, {}
local next_id, now, game_thread = 0, 0, false
local actors, anims, settings, output = {}, {}, {}, {}
local class, fail_hook
local loaded_functions = {}
local CHOREO_CLASS = "/Game/Game/Cinematics/Blueprints/Stage/StateMachine/SMstate_PlayChoreographedSequence.SMstate_PlayChoreographedSequence_C"
local scans, anim_searches, rate_writes, settings_registrations = 0, 0, 0, 0
local active_montage_reads = 0
local function on_game_thread() assert(game_thread, "Unreal work during loader initialization") end
local function wrap(obj) return { get = function() return obj end } end
local function object(name)
    return {
        alive = true,
        IsValid = function(self) on_game_thread(); return self.alive end,
        GetFullName = function() on_game_thread(); return name end,
    }
end
local function world(id)
    local value = object("World " .. id)
    value.GetAddress = function() return id end
    value.PersistentLevel = object("Level " .. id)
    value.PersistentLevel.OwningWorld = value
    return value
end
local worlds = {A = world("A"), B = world("B")}
-- In-game validation: mission actors report the streamed Gameplay world, while
-- humanoid animation instances and cinematic states report the Root world.
local mission_worlds = {A = world("A_Gameplay"), B = world("B_Gameplay")}
for id, value in pairs(mission_worlds) do value.PersistentLevel.OwningWorld = worlds[id] end
local function mission_actor(id)
    local actor = object("BP_MissionActor_C /Game/Mission" .. id .. ".World.PersistentLevel.Mission")
    actor.GetWorld = function() return mission_worlds[id] end
    actor.bIsMissionActorReady, actor.MissionStatus, actor.bIsMissionEnding = false, 0, false
    actor.IsA = function(_, path) on_game_thread(); return path == "/Script/BitReactorGame.BRGameMissionActor" end
    actor.HasAnyFlags = function(self) on_game_thread(); return self.template == true end
    return actor
end
function RegisterHook(path, pre, post)
    on_game_thread()
    assert(not hooks[path], "duplicate hook " .. path)
    if path == fail_hook then error("function not ready") end
    next_id = next_id + 2
    hooks[path] = {pre = pre, post = post, pre_id = next_id - 1, post_id = next_id}
    return next_id - 1, next_id
end
function UnregisterHook(path, pre_id, post_id)
    local hook = assert(hooks[path])
    assert(hook.pre_id == pre_id and hook.post_id == post_id)
    hooks[path] = nil
end
function NotifyOnNewObject(path, callback)
    on_game_thread()
    notifications[path] = notifications[path] or {}
    table.insert(notifications[path], callback)
end
function RegisterLoadMapPreHook(callback) on_game_thread(); table.insert(lifecycle, {map = callback}) end
function RegisterEndPlayPreHook(callback) on_game_thread(); table.insert(lifecycle, {ending = callback}) end
function MakeActionHandle() next_id = next_id + 1; return next_id end
function ExecuteInGameThreadWithDelay(handle, delay, callback)
    queue[handle] = {due = now + delay, callback = callback}
end
function CancelDelayedAction(handle) cancelled[handle] = true; return queue[handle] ~= nil end
function IsValidDelayedActionHandle(handle) return queue[handle] ~= nil and not cancelled[handle] end
IsDelayedActionActive = IsValidDelayedActionHandle
function ClearAllDelayedActions()
    for handle in pairs(queue) do cancelled[handle] = true end
end
function FindAllOf(name)
    on_game_thread(); scans = scans + 1
    assert(name ~= "AnimMontage", "must not scan resident montages")
    if name == "BRGameMissionActor" then return actors end
    assert(name == "AnimInstance")
    anim_searches = anim_searches + 1
    return anims
end
-- UE4SS's string overload requires an exact class name. Blueprint-generated
-- classes are not instances of the native metaclass named "Class".
function FindObject(class_name, name)
    on_game_thread(); assert(name == "SMstate_PlayChoreographedSequence_C")
    if class_name == "SMNodeBlueprintGeneratedClass" then return class end
end
function StaticFindObject(path)
    on_game_thread()
    if path == CHOREO_CLASS then return class end
    assert(path:sub(1, #CHOREO_CLASS + 1) == CHOREO_CLASS .. ":")
    return loaded_functions[path]
end
package.loaded.MXM = {
    Get = function(key, fallback) if settings[key] ~= nil then return settings[key] end; return fallback end,
    IsAvailable = function() return false end,
    OnChange = function() settings_registrations = settings_registrations + 1 end,
}
local original_print, original_open = print, io.open
print = function(line) table.insert(output, line) end
io.open = function() return nil, "disabled by test" end
local function pump(ms)
    local until_time = now + (ms or 0)
    game_thread = true
    for _ = 1, 1000 do
        local selected
        for handle, action in pairs(queue) do
            if action.due <= until_time and (not selected or action.due < queue[selected].due
                or (action.due == queue[selected].due and handle < selected)) then selected = handle end
        end
        if not selected then now = until_time; game_thread = false; return end
        local action = queue[selected]; queue[selected] = nil; now = action.due
        if not cancelled[selected] then action.callback() end
    end
    error("unbounded scheduler")
end
local function event(fn, ...)
    game_thread = true; fn(...); game_thread = false
end
local function notify(path, obj)
    for _, callback in ipairs(notifications[path] or {}) do event(callback, obj) end
end
local function pending()
    local result = {}
    for handle in pairs(FastResonanceRuntime.actions) do
        if queue[handle] and not cancelled[handle] then table.insert(result, handle) end
    end
    return result
end
local function reload()
    local before_scans = scans
    assert(loadfile(scripts .. "/main.lua"))()
    assert(scans == before_scans, "reload performed loader-side object discovery")
    assert(#pending() == 1, "loader must publish exactly one bootstrap action")
end
local CLASS = "/Script/BitReactorGame.BRGameMissionActor"
local CHOREO = CHOREO_CLASS .. ":"
local SAVE = "/Game/Game/LevelDesign/EncounterLogic/BP_MissionActor.BP_MissionActor_C:PostLoadFromSave"
local DELAY = "/Script/Engine.KismetSystemLibrary:Delay"
local function ready(actor)
    actor.bIsMissionActorReady, actor.MissionStatus = true, 1
    event(hooks[CLASS .. ":HandleMapBeginPlayReceived"].post, wrap(actor))
    pump()
end
reload()
assert(next(hooks) == nil and next(notifications) == nil and scans == 0)
pump()
assert(scans == 1 and not hooks[DELAY], "menu bootstrap must only look for a mission")
assert(#pending() == 0, "no permanent menu readiness poll")
local actor = mission_actor("A")
actor.template = true
notify(CLASS, actor); pump()
assert(#pending() == 0, "CDOs must not activate mission readiness")
actor.template = false; actors = {actor}
notify(CLASS, actor); pump()
assert(not hooks[DELAY], "construction is not mission readiness")
pump(5000)
assert(#pending() == 0 and table.concat(output):find("Mission readiness timed out", 1, true))

local functions = {}
for _, short in ipairs({"Sequence Play", "Play Sequence", "OnStateBegin"}) do
    functions[#functions + 1] = object("Function " .. CHOREO .. short)
end
class = object("SMNodeBlueprintGeneratedClass " .. CHOREO_CLASS)
class.ForEachFunction = function(_, callback) on_game_thread(); for _, fn in ipairs(functions) do callback(fn) end end
-- A class may already exist while its functions have not finished loading.
ready(actor)
pump(2000)
assert(hooks[DELAY] and not hooks[CHOREO .. "Sequence Play"])
assert(#pending() == 0, "missing choreography functions must not poll forever")
assert(table.concat(output):find("Sequence Play (not loaded)", 1, true))

-- A later generated-class event starts bounded recovery; individual functions
-- can become available at different times, and hook installation can fail.
loaded_functions[CHOREO .. "Sequence Play"] = functions[1]
loaded_functions[CHOREO .. "Play Sequence"] = functions[2]
notify("/Script/CoreUObject.Class", class); pump()
assert(hooks[CHOREO .. "Sequence Play"] and not hooks[CHOREO .. "OnStateBegin"])
fail_hook = CHOREO .. "OnStateBegin"
loaded_functions[fail_hook] = functions[3]
pump(50)
assert(not hooks[fail_hook])
fail_hook = nil
pump(100)
assert(hooks[CHOREO .. "OnStateBegin"], "partial hook installation must retry")
assert(#pending() == 0)
assert(table.concat(output):find("Choreography hooks ready | 3/3", 1, true))

local function array(values)
    values.ForEach = function(self, callback) for i, v in ipairs(self) do callback(i - 1, wrap(v)) end end
    return values
end
local asset = object("AnimSequence /Game/Coil_PlagueTransfer_Surge")
local montage = object("AnimMontage /Game/Test.Reused")
montage.SlotAnimTracks = array({{AnimTrack = {AnimSegments = array({{AnimReference = asset}})}}})
local anim = object("AnimInstance /Game/MissionA.ABP_BR_Humanoid_Base_C_1")
anim.GetWorld = function() return worlds.A end
anim.GetCurrentActiveMontage = function()
    on_game_thread(); active_montage_reads = active_montage_reads + 1; return montage
end
anim.Montage_GetPlayRate = function(self) return self.rate or 1 end
anim.Montage_GetEffectivePlayRate = anim.Montage_GetPlayRate
anim.Montage_GetPosition = function() return 0 end
anim.Montage_SetPlayRate = function(self, _, rate) on_game_thread(); self.rate = rate; rate_writes = rate_writes + 1 end
anims = {anim}
local seeded_searches = anim_searches
notify("/Script/Engine.AnimInstance", anim)
notify("/Script/Engine.AnimMontage", montage)
local stale = {}
for _, handle in ipairs(pending()) do stale[#stale + 1] = queue[handle].callback end
pump()
assert(anim.rate == 4 and #pending() == 0, "successful montage must cancel its retries")

-- The captured SM_Resonate body animations use the transfer setting independently
-- of camera readiness. Exercise actual constructor retries.
local surge_montage = montage
for index, asset_name in ipairs({
    "A_1HPistol_Coil_Captain_Resonance",
    "A_2HRifle_Coil_PlagueTransfer_NonSurge",
    "A_1HPistol_Crouch_Turn_L_90", -- nearby unrelated animation from the capture
}) do
    montage = object("AnimMontage /Game/Test.Captured_" .. index)
    montage.SlotAnimTracks = array({{AnimTrack = {AnimSegments = array({{
        AnimReference = object("AnimSequence /Game/" .. asset_name .. "." .. asset_name),
    }})}}})
    settings.resonance_transfer_speed = 3
    anim.rate = 1
    local before = rate_writes
    notify("/Script/Engine.AnimMontage", montage); pump(250)
    if index <= 2 then
        assert(anim.rate == 3 and rate_writes == before + 1, asset_name .. " must use transfer speed")
        settings.resonance_transfer_enabled = false
        notify("/Script/Engine.AnimMontage", montage); pump(250)
        assert(anim.rate == 1, asset_name .. " must respect the transfer enable switch")
        settings.resonance_transfer_enabled = true
        settings.resonance_transfer_speed = 2
        notify("/Script/Engine.AnimMontage", montage); pump(250)
        assert(anim.rate == 2, asset_name .. " must pick up changed settings")
    else
        assert(anim.rate == 1 and rate_writes == before, "unrelated turning animation must stay unchanged")
    end
    assert(#pending() == 0)
end
-- Unnatural Resilience has independent settings and must not affect the Brute's
-- ordinary rifle animation captured immediately after the ability.
settings.resonance_transfer_enabled = false
settings.shared_suffering_enabled = false
for index, asset_name in ipairs({
    "A_2HRifle_Coil_Brute_Tenacity_Start",
    "A_2HRifle_Aim_Enter_0",
}) do
    montage = object("AnimMontage /Game/Test.Tenacity_" .. index)
    montage.SlotAnimTracks = array({{AnimTrack = {AnimSegments = array({{
        AnimReference = object("AnimSequence /Game/" .. asset_name .. "." .. asset_name),
    }})}}})
    anim.rate = 1
    local before = rate_writes
    notify("/Script/Engine.AnimMontage", montage); pump(250)
    if index == 1 then
        assert(anim.rate == 4 and rate_writes == before + 1, "Tenacity must default to 4x independently")
        settings.unnatural_resilience_speed = 3
        notify("/Script/Engine.AnimMontage", montage); pump(250)
        assert(anim.rate == 3, "Tenacity must use its own multiplier")
        settings.unnatural_resilience_enabled = false
        notify("/Script/Engine.AnimMontage", montage); pump(250)
        assert(anim.rate == 1, "disabled Tenacity must restore vanilla speed")
        settings.unnatural_resilience_enabled = true
    else
        assert(anim.rate == 1 and rate_writes == before, "ordinary rifle aiming must stay unchanged")
    end
    assert(#pending() == 0)
end
settings.unnatural_resilience_speed = nil
settings.resonance_transfer_enabled = true
settings.shared_suffering_enabled = true
montage = surge_montage
settings.resonance_transfer_speed = nil
anim.rate = 4

local player = object("Player Test")
player.SetPlayRate = function(self, rate) self.rate = rate end
player.GetPlayRate = function(self) return self.rate or 1 end
local sequence_actor = object("LevelSequenceActor Test")
sequence_actor.GetSequencePlayer = function() return player end
local state = object("SMstate_PlayChoreographedSequence_C /Game/MissionA.State")
state.GetWorld = function() return worlds.A end
state["Level Sequence"] = object("LevelSequence /Game/LS_AG_PlagueTransfer_Surge_Test")
state.LevelSequenceActor = sequence_actor
-- Invalid or unrelated worlds must not allow playback writes.
local state_world = state.GetWorld
local before_rejected = rate_writes
state.GetWorld = function() error("test world lookup error") end
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(rate_writes == before_rejected and player.rate == nil)
state.GetWorld = function() return nil end
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(rate_writes == before_rejected and player.rate == nil)
state.GetWorld = function() return worlds.B end
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(rate_writes == before_rejected and player.rate == nil)
state.GetWorld = state_world
-- Streaming ownership must be ready and acyclic; do not accept an unresolved
-- world merely because the map's name resembles the current mission.
mission_worlds.A.PersistentLevel.OwningWorld = nil
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(rate_writes == before_rejected and player.rate == nil)
mission_worlds.A.PersistentLevel.OwningWorld = worlds.A
worlds.A.PersistentLevel.OwningWorld = mission_worlds.A
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(rate_writes == before_rejected and player.rate == nil)
worlds.A.PersistentLevel.OwningWorld = worlds.A
settings.resonance_transfer_speed = 2
-- The same montage object need not be constructed again for the next playback.
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(anim.rate == 2 and player.rate == 2, "presentation must refresh a reused montage")
settings.resonance_transfer_enabled = false
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(anim.rate == 1 and player.rate == 1, "disabled settings restore vanilla on reused players")
settings.resonance_transfer_enabled = true
local target_sequence = state["Level Sequence"]
state["Level Sequence"] = nil
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
state["Level Sequence"] = target_sequence
pump(5)
assert(anim.rate == 2 and player.rate == 2, "late sequence assignment must remain retryable")

-- Playback reuses the known owner without a second pass or background probes.
local reads_before, writes_before = active_montage_reads, rate_writes
event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(state)); pump()
assert(active_montage_reads == reads_before + 1, "presentation must not search twice for the same owner")
assert(rate_writes == writes_before + 1 and #pending() == 0)
pump(1000)
assert(active_montage_reads == reads_before + 1 and rate_writes == writes_before + 1,
    "successful presentation must leave no background playback work")
assert(anim_searches == seeded_searches, "all playback and settings changes must use the mission cache")
assert(not table.concat(output):find("HITCH", 1, true), "release must not emit temporary hitch diagnostics")

-- Generic camera assets are eligible only within the captured ability instance.
-- Cover both Resonate stages, all hook entry points, and independent settings.
do
    local generic_sequence = object("LevelSequence /Game/Test.GenericCamera")
    local camera_writes = 0
    local camera_player = object("Player AbilityCamera")
    camera_player.GetPlayRate = function(self) return self.rate or 1 end
    camera_player.SetPlayRate = function(self, rate)
        self.rate = rate; camera_writes = camera_writes + 1
    end
    local camera_actor = object("LevelSequenceActor AbilityCamera")
    camera_actor.GetSequencePlayer = function() return camera_player end
    local function camera_state(machine, stage)
        local value = object("SMstate_PlayChoreographedSequence_C /Game/MissionA.Runner."
            .. machine .. ".SMstate_PlayChoreographedSequence_C_" .. (stage or 0))
        value.GetWorld = function() return worlds.A end
        value["Level Sequence"], value.LevelSequenceActor = generic_sequence, camera_actor
        return value
    end
    settings.resonance_transfer_speed, settings.unnatural_resilience_speed = 3, 5
    for _, machine in ipairs({"SM_Resonate_C_12", "SM_Tenacity_C_7"}) do
        local tenacity = machine:find("Tenacity", 1, true) ~= nil
        local key = tenacity and "unnatural_resilience_enabled" or "resonance_transfer_enabled"
        for stage = 0, 1 do
            local ability_state = camera_state(machine, stage)
            for _, entry in ipairs({"OnStateBegin", "Play Sequence", "Sequence Play"}) do
                local before = camera_writes
                event(hooks[CHOREO .. entry].pre, wrap(ability_state)); pump(300)
                assert(camera_writes == before + 1 and camera_player.rate == (tenacity and 5 or 3))
            end
            settings[key] = false
            event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(ability_state)); pump(300)
            assert(camera_player.rate == 1, "disabling an ability must reset its reused camera")
            settings[key] = true
        end
    end
    for _, machine in ipairs({"SM_Unrelated_C_1", "Other_SM_Resonate_C_1",
        "SM_Tenacity_C_7Extra", "SM_Resonate_C_", "SM_Tenacity_C_Default"}) do
        local before = camera_writes
        event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(camera_state(machine))); pump(300)
        assert(camera_writes == before, "generic cameras outside exact ability instances must be untouched")
    end
    local late_state = camera_state("SM_Tenacity_C_25")
    late_state["Level Sequence"], late_state.LevelSequenceActor = nil, nil
    local before = camera_writes
    event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(late_state)); pump()
    assert(camera_writes == before, "a context match alone must not write without a sequence/player")
    late_state["Level Sequence"] = generic_sequence
    pump(5)
    assert(camera_writes == before)
    late_state.LevelSequenceActor = camera_actor
    pump(10)
    assert(camera_writes == before + 1 and camera_player.rate == 5, "late camera readiness must retry")
    pump(1000)
    late_state.GetWorld = function() return worlds.B end
    before = camera_writes
    event(hooks[CHOREO .. "OnStateBegin"].pre, wrap(late_state)); pump(300)
    assert(camera_writes == before, "ability-scoped cameras must still belong to the active mission")
    assert(anim_searches == seeded_searches, "new camera coverage must not reintroduce global searches")
    assert(table.concat(output):find("kind=unnatural-resilience-camera", 1, true))
    assert(table.concat(output):find("kind=resonate-camera", 1, true))
    settings.resonance_transfer_speed, settings.unnatural_resilience_speed = 2, nil
end

-- An instance created after mission readiness is retained before its world is
-- ready, then accepted at playback. No emergency global search is required.
local original_active = anim.GetCurrentActiveMontage
anim.GetCurrentActiveMontage = function() return nil end
local late_world
local late_anim = object("AnimInstance /Game/MissionA.ABP_BR_Humanoid_Base_C_Late")
late_anim.GetWorld = function() return late_world end
late_anim.GetCurrentActiveMontage = original_active
late_anim.Montage_GetPlayRate = anim.Montage_GetPlayRate
late_anim.Montage_GetEffectivePlayRate = anim.Montage_GetEffectivePlayRate
late_anim.Montage_GetPosition = anim.Montage_GetPosition
late_anim.Montage_SetPlayRate = anim.Montage_SetPlayRate
notify("/Script/Engine.AnimInstance", late_anim)
notify("/Script/Engine.AnimMontage", montage); pump()
assert(late_anim.rate == nil, "not-yet-owned instances must not be written")
late_world = worlds.A
pump(250)
assert(late_anim.rate == 2 and anim_searches == seeded_searches, "late instance must become usable without a search")

-- Invalidated entries are evicted; replacements with the same name are accepted.
late_anim.alive = false
local writes_before_destroyed = rate_writes
notify("/Script/Engine.AnimMontage", montage); pump(250)
assert(rate_writes == writes_before_destroyed, "destroyed instances must never receive rate writes")
local replacement = object("AnimInstance /Game/MissionA.ABP_BR_Humanoid_Base_C_Late")
for key, value in pairs(late_anim) do
    if key ~= "alive" and key ~= "GetFullName" and key ~= "rate" then replacement[key] = value end
end
notify("/Script/Engine.AnimInstance", replacement)
notify("/Script/Engine.AnimMontage", montage); pump(250)
assert(replacement.rate == 2 and anim_searches == seeded_searches)
replacement.alive = false
anim.GetCurrentActiveMontage = original_active

-- A construction notification can arrive before the montage has tracks.
local ready_montage = montage
montage = object("AnimMontage /Game/Test.LateTracks")
montage.SlotAnimTracks = array({})
anim.rate = 1
notify("/Script/Engine.AnimMontage", montage); pump()
assert(anim.rate == 1 and #pending() == 1, "unready montage gets only one pending retry")
montage.SlotAnimTracks = ready_montage.SlotAnimTracks
pump(250)
assert(anim.rate == 2 and #pending() == 0, "late tracks must still be detected")
montage = ready_montage

-- Reproduce the scale of the recorded mission-start burst: 440 montages must
-- never create 5,720 simultaneously queued retries or trigger owner searches.
for index = 1, 440 do
    local unrelated = object("AnimMontage /Game/Test.Burst_" .. index)
    unrelated.SlotAnimTracks = array({{AnimTrack = {AnimSegments = array({{
        AnimReference = object("AnimSequence /Game/OrdinaryMovement"),
    }})}}})
    notify("/Script/Engine.AnimMontage", unrelated)
end
assert(#pending() == 440, "one queued callback per montage, not 13")
local previous = 0
for _, due in ipairs({0, 2, 5, 10, 15, 20, 30, 45, 60, 90, 130, 180, 250}) do
    pump(due - previous)
    previous = due
    assert(#pending() <= 440)
end
assert(#pending() == 0 and anim_searches == seeded_searches)

local duration = { get = function() return 2 end, set = function(self, value) self.value = value end }
local delay_world = object("State /Game/MissionA.SM_SharedSuffering_C_1.SMstate_SimpleDelay_C_1")
delay_world.GetWorld = function() return worlds.A end
event(hooks[DELAY].pre, wrap(nil), wrap(delay_world), duration)
assert(duration.value == 0.5)

-- Same-world save loads replace the session and cancel callbacks already dispatched.
notify("/Script/Engine.AnimMontage", montage)
local old_callbacks = {}
for _, handle in ipairs(pending()) do old_callbacks[#old_callbacks + 1] = queue[handle].callback end
actor.bIsMissionActorReady = false
event(hooks[SAVE].pre, wrap(actor))
local writes = rate_writes
for _, callback in ipairs(old_callbacks) do event(callback) end
assert(rate_writes == writes)
actor.bIsMissionActorReady = true; pump()
assert(rate_writes > writes, "save-load readiness must recover live presentation")

notify("/Script/Engine.AnimMontage", montage)
event(hooks[CLASS .. ":SetIsMissionEnding"].pre, wrap(actor), wrap(true))
actor.bIsMissionEnding = true
for _, callback in ipairs(stale) do event(callback) end
assert(#pending() == 0)
local before = rate_writes
notify("/Script/Engine.AnimMontage", montage); pump()
assert(rate_writes == before, "no combat work after mission end")
duration.value = nil
event(hooks[DELAY].pre, wrap(nil), wrap(delay_world), duration)
assert(duration.value == nil)

-- New world and ordinary map travel without a mission-completion event.
local actor2 = mission_actor("B"); actors = {actor2}; anims = {}
ready(actor2)
local old_world_writes = rate_writes
anims = {anim}
notify("/Script/Engine.AnimInstance", anim)
notify("/Script/Engine.AnimMontage", montage); pump(250)
assert(rate_writes == old_world_writes, "never modify an animation instance in the retired world")
anims = {}
notify("/Script/Engine.AnimMontage", montage)
for _, listener in ipairs(lifecycle) do if listener.map then assert(event(listener.map) == nil) end end
assert(#pending() == 0)
ready(actor2)
notify("/Script/Engine.AnimMontage", montage)
for _, listener in ipairs(lifecycle) do if listener.ending then event(listener.ending, wrap(actor2)) end end
assert(#pending() == 0)

-- Reload already in combat: no new mission/constructor event is necessary.
anims = {anim}; actor2.bIsMissionActorReady = true
anim.GetWorld = function() return worlds.B end
local first, old_hook = FastResonanceRuntime, hooks[CHOREO .. "OnStateBegin"].pre
reload()
assert(not first.alive)
event(old_hook, wrap(state))
pump()
assert(hooks[CHOREO .. "OnStateBegin"] and anim.rate == 2)
assert(#notifications["/Script/Engine.AnimMontage"] == 1)
assert(#notifications["/Script/Engine.AnimInstance"] == 1)
assert(#notifications["/Script/CoreUObject.Class"] == 1)
assert(#notifications[CLASS] == 1 and #lifecycle == 2 and settings_registrations == 1)

-- Reload before the first handoff: the abandoned bootstrap cannot install hooks.
reload()
local abandoned = queue[pending()[1]].callback
reload(); event(abandoned); pump()
assert(#notifications[CLASS] == 1)
-- A reload between construction and readiness must not need another event.
actor2.bIsMissionActorReady = false
reload(); pump()
assert(not hooks[DELAY] and #pending() == 1)
actor2.bIsMissionActorReady = true
pump(50)
assert(hooks[DELAY])
FastResonanceRuntime:teardown("test complete")
assert(next(hooks) == nil)
-- Failed native setup must retire partially installed hooks and callbacks.
fail_hook = CLASS .. ":SetIsMissionEnding"
reload()
local setup_ok = pcall(pump)
game_thread = false
assert(not setup_ok and not FastResonanceRuntime.alive and next(hooks) == nil)
assert(table.concat(output):find("game-thread setup failed", 1, true))
print, io.open = original_print, original_open
print("Fast Resonance game-thread bootstrap, mission readiness, presentation and reload tests passed")
