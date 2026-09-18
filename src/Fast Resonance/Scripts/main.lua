-- Fast Resonance v1.0.5
-- Loader-thread composition only. Do not scan UObjects or register feature
-- callbacks here: zero-delay retries can otherwise run during registration.
local VERSION = "1.0.5"
for _, module in ipairs({"hook_registry", "actions", "logging", "mission", "feature"}) do
    package.loaded[module] = nil
end
local Runtime = require("hook_registry")
local Actions = require("actions")
local Logging = require("logging")
local Feature = require("feature")
local runtime = Runtime.start("FastResonanceRuntime", {
    clear_all = FastResonanceClearDelayedActionsOnReload ~= false,
})
local logger = Logging.new(runtime, { tag = "[FastResonance]" })
local actions = Actions.new(runtime, {
    valid = function(obj)
        if not obj then return false end
        local ok, result = pcall(function() return obj:IsValid() end)
        return ok and result == true
    end,
    log = function(...) logger:log(...) end,
})
logger:transition("runtime", "loading", "version=" .. VERSION)
if logger.LOG_PATH then
    logger:log("Dedicated log | %s", logger.LOG_PATH)
else
    logger:log("WARNING: fast_resonance.log unavailable; diagnostics remain in UE4SS.log")
end

-- This MUST remain the final operation. Publish one callback, then return
-- without touching the hook Lua stack again. All subsequent hook installation,
-- mission discovery and retry submission takes place on the game thread.
return actions:schedule_after("bootstrap", 0, function()
    local ok, err = pcall(function()
        Feature.start(runtime, actions, logger, require("MXM"), require("targets"), VERSION)
    end)
    if not ok then
        logger:log("ERROR: game-thread setup failed | %s", tostring(err))
        runtime:teardown("setup failed")
        error(err)
    end
end)
