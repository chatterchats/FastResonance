-- main.lua against a mocked UE4SS: node templates of enabled abilities are sped up from their
-- vanilla values, sequences play at the set speed and are reset when they end, and disabled
-- abilities and other state machines stay vanilla. Run from the repo root (make test).
package.path = "src/Fast Resonance/Scripts/?.lua;" .. package.path

local CHOREO = "/Game/Game/Cinematics/Blueprints/Stage/StateMachine/SMstate_PlayChoreographedSequence.SMstate_PlayChoreographedSequence_C"
local DELAY = "/Game/Game/Cinematics/Blueprints/Stage/StateMachine/SMstate_SimpleDelay.SMstate_SimpleDelay_C"
local BROADCASTER = "/Game/Game/Abilities/Humanoid/Coil/PlagueBroadcaster/SMN_PlagueBroadcaster.SMN_PlagueBroadcaster_C"

-- MXM config stub
local settings, on_change = {}, nil
package.preload["MXM"] = function()
    return {
        Get = function(key, default)
            if settings[key] == nil then return default end
            return settings[key]
        end,
        OnChange = function(fn) on_change = fn end,
    }
end

local function valid(t)
    t.IsValid = function() return true end
    return t
end

local function template(name, props)
    local t = valid(props)
    t.GetFullName = function() return name end
    return t
end

-- Node templates the game would have loaded with a mission.
local tenacity_hold = template("SMstate_SimpleDelay_C /Game/X/SM_Tenacity.SM_Tenacity_C:TEMPLATE_SimpleDelay_1",
    {["Delay Time"] = 2.0})
local foreign_hold = template("SMstate_SimpleDelay_C /Game/X/SM_Unrelated.SM_Unrelated_C:TEMPLATE_SimpleDelay_1",
    {["Delay Time"] = 2.0})
local bridge = template("SMN_PlagueBroadcaster_C /Game/X/SM_PlagueBroadcaster.SM_PlagueBroadcaster_C:TEMPLATE_Bridge_1",
    {BridgeBuildTime = 1.0, DelayToTransferAfterBridgeBuild = 0.5, BridgeBuildTimeDelayForAudio = 0.2,
     ["Distance Covered PreSecond"] = 100.0})
local templates = {[DELAY] = {tenacity_hold, foreign_hold}, [BROADCASTER] = {bridge}}

-- UE4SS stubs
local queue, hooks, logs = {}, {}, {}
function print(text) logs[#logs + 1] = text end
function MakeActionHandle() return {} end
function ExecuteInGameThreadWithDelay(_, _, fn) queue[#queue + 1] = fn end
function StaticFindObject(path) return valid({path = path:gsub(":.*", "")}) end
function FindObjects(_, class) return templates[class.path] or {} end
function RegisterHook(path, fn) hooks[path] = fn end
function NotifyOnNewObject() end

local function flush()
    while #queue > 0 do table.remove(queue, 1)() end
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

local count = 0
local function play(machine)
    count = count + 1
    local player = valid({rate = 1.0, IsPlaying = function() return true end})
    player.SetPlayRate = function(self, r) self.rate = r end
    local sequence = valid({GetFName = function() return {ToString = function() return "LS_" .. machine end} end})
    local state = valid({})
    state.LevelSequenceActor = valid({
        GetSequencePlayer = function() return player end,
        GetSequence = function() return sequence end,
    })
    local name = "SMstate_PlayChoreographedSequence_C /Game/Map.Map:SMRunner_" .. count
        .. "." .. machine .. "_C_0.SMstate_PlayChoreographedSequence_C_1"
    state.GetFullName = function() return name end
    local ctx = {get = function() return state end}
    hooks[CHOREO .. ":OnStateBegin"](ctx)
    flush()
    return player, function() hooks[CHOREO .. ":OnStateEnd"](ctx) end
end

dofile("src/Fast Resonance/Scripts/main.lua")
flush()
assert(hooks[CHOREO .. ":OnStateBegin"] and hooks[CHOREO .. ":OnStateEnd"], "sequence hooks install")

-- Default speed 4x on every ability.
assert(near(tenacity_hold["Delay Time"], 0.5), "hold divided by speed")
assert(near(bridge.BridgeBuildTime, 0.25) and near(bridge["Distance Covered PreSecond"], 400), "bridge times and rates")
assert(foreign_hold["Delay Time"] == 2.0, "other state machines stay vanilla")

local player, finish = play("SM_Tenacity")
assert(player.rate == 4.0, "ability sequence plays at the set speed")
finish()
assert(player.rate == 1.0, "a reused sequence player is reset when the state ends")
assert(play("SM_Unrelated").rate == 1.0, "non-Coil sequences are untouched")

-- Changing settings recomputes from the vanilla values, not the already-patched ones.
settings.speed = 2.0
settings.unnatural_resilience_enabled = false
on_change()
assert(tenacity_hold["Delay Time"] == 2.0, "a disabled ability returns to vanilla")
assert(near(bridge.BridgeBuildTime, 0.5), "others follow the new speed from vanilla")
assert(play("SM_Tenacity").rate == 1.0, "a disabled ability's sequence plays at 1x")
assert(play("SM_PlagueBroadcaster").rate == 2.0)

settings.speed = 100
on_change()
assert(near(bridge.BridgeBuildTime, 1.0 / 8), "speed is clamped to 8x")

print = io.write
io.write("main_test: ok\n")
