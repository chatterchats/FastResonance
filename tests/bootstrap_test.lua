-- Run from repository root: luajit tests/bootstrap_test.lua "src/Fast Resonance/Scripts"
local scripts = assert(arg[1], "pass the mod Scripts directory")
package.path = scripts .. "/?.lua;" .. package.path

local hooks, notifications, queue, cancelled = {}, {}, {}, {}
local next_id, unregister_count, clear_count, settings_registrations = 0, 0, 0, 0

function RegisterHook(path, pre, post)
    assert(hooks[path] == nil, "duplicate hook: " .. path)
    next_id = next_id + 2
    hooks[path] = { pre = pre, post = post, pre_id = next_id - 1, post_id = next_id }
    return next_id - 1, next_id
end

function UnregisterHook(path, pre_id, post_id)
    local hook = assert(hooks[path], "unknown hook: " .. path)
    assert(hook.pre_id == pre_id and hook.post_id == post_id)
    hooks[path] = nil
    unregister_count = unregister_count + 1
end

function NotifyOnNewObject(path, callback)
    notifications[path] = notifications[path] or {}
    notifications[path][#notifications[path] + 1] = callback
end

function MakeActionHandle()
    next_id = next_id + 1
    return next_id
end

function ExecuteInGameThreadWithDelay(handle, delay, callback)
    assert(type(delay) == "number")
    queue[handle] = callback
end

function CancelDelayedAction(handle)
    cancelled[handle] = true
    return queue[handle] ~= nil
end

function IsValidDelayedActionHandle(handle)
    return queue[handle] ~= nil and not cancelled[handle]
end

IsDelayedActionActive = IsValidDelayedActionHandle

function ClearAllDelayedActions()
    clear_count = clear_count + 1
    return 0
end

function FindAllOf() return {} end
function FindObject() return nil end

local Settings = {}
Settings.Get = function(_, fallback) return fallback end
Settings.IsAvailable = function() return false end
Settings.OnChange = function(callback)
    settings_registrations = settings_registrations + 1
    Settings.callback = callback
end
package.loaded.MXM = Settings
package.loaded.targets = nil

local original_print = print
print = function() end
assert(loadfile(scripts .. "/main.lua"))()
local first = assert(FastResonanceRuntime)
assert(first.generation == 1 and first.alive)
assert(hooks["/Script/Engine.KismetSystemLibrary:Delay"])
assert(#notifications["/Script/Engine.AnimMontage"] == 1)
assert(#notifications["/Script/CoreUObject.Class"] == 1)
assert(settings_registrations == 1)

local montage = {
    SlotAnimTracks = {},
    IsValid = function() return true end,
    GetFullName = function() return "AnimMontage /Game/Test.NonTarget" end,
}
notifications["/Script/Engine.AnimMontage"][1](montage)
local pending = {}
for handle in pairs(first.actions) do pending[#pending + 1] = handle end
assert(#pending == 13, "montage readiness retries must be owned")

assert(loadfile(scripts .. "/main.lua"))()
local second = assert(FastResonanceRuntime)
assert(not first.alive and second.alive and second.generation == 2)
assert(unregister_count == 1, "the prior Delay hook must be unregistered")
assert(hooks["/Script/Engine.KismetSystemLibrary:Delay"])
assert(#notifications["/Script/Engine.AnimMontage"] == 1,
    "continuous montage observer must reuse its dispatcher")
assert(settings_registrations == 1, "MXM handler must reuse its dispatcher")
assert(clear_count == 3)
for _, handle in ipairs(pending) do
    assert(cancelled[handle], "reload must cancel every pending retry")
    queue[handle]() -- A callback already copied for dispatch must remain inert.
end

-- The old broad class observer cannot be removed externally. It retires itself
-- the next time it fires; the current generation remains active.
local class_callbacks = notifications["/Script/CoreUObject.Class"]
assert(#class_callbacks == 2)
local other_class = {
    IsValid = function() return true end,
    GetFullName = function() return "Class /Game/Test.Other_C" end,
}
assert(class_callbacks[1](other_class) == true)
assert(class_callbacks[2](other_class) == false)

local choreo_function = {
    IsValid = function() return true end,
    GetFullName = function()
        return "Function /Game/Test.SMstate_PlayChoreographedSequence_C:OnStateBegin"
    end,
}
local choreo_class = {
    IsValid = function() return true end,
    GetFullName = function()
        return "Class /Game/Test.SMstate_PlayChoreographedSequence_C"
    end,
    ForEachFunction = function(_, callback) callback(choreo_function) end,
}
assert(class_callbacks[2](choreo_class) == true)
local discovery_handle = next(second.actions)
assert(discovery_handle, "class discovery must be deferred through an owned action")
local discovery_callback = assert(queue[discovery_handle])
queue[discovery_handle] = nil
discovery_callback()
assert(hooks["/Game/Test.SMstate_PlayChoreographedSequence_C:OnStateBegin"])

second:teardown("test complete")
print = original_print
assert(unregister_count == 3 and clear_count == 4)
print("Fast Resonance bootstrap and same-state reload tests passed")
