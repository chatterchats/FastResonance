-- Mission sessions. Construct and install only after the game-thread handoff.
local M = {}
local CLASS = "/Script/BitReactorGame.BRGameMissionActor"
local SAVE_HOOK = "/Game/Game/LevelDesign/EncounterLogic/BP_MissionActor.BP_MissionActor_C:PostLoadFromSave"
local READY_MS = {0, 50, 100, 250, 500, 1000, 2000, 5000}

function M.new(runtime, actions, options)
    local valid, read, name, unwrap = options.valid, options.read, options.name, options.unwrap
    local self = { generation = 0, actor = nil, active = false }

    local function is_mission(actor)
        if not valid(actor) then return false end
        local ok, result = pcall(function()
            return actor:IsA(CLASS) and not actor:HasAnyFlags(0x30) -- CDO / archetype
        end)
        return ok and result == true
    end

    local function ready(actor)
        return valid(actor)
            and read(actor, "bIsMissionActorReady") == true
            and read(actor, "MissionStatus") == 1 -- EMissionStatus.Active
            and read(actor, "bIsMissionEnding") == false
    end

    function self:stop(reason)
        self.generation = self.generation + 1
        self.active = false
        self.actor = nil
        self.actor_name = nil
        actions:cancel_all(reason)
        options.on_stop(reason)
    end

    function self:is_active()
        if not runtime.alive or not self.active then return false end
        if not ready(self.actor) then
            self:stop("mission no longer ready")
            return false
        end
        return true
    end

    function self:schedule(group, delay, callback, ...)
        if not self:is_active() then return end
        local generation = self.generation
        return actions:schedule_after(group, delay, function()
            if self.generation == generation and self:is_active() then callback() end
        end, ...)
    end

    local function owning_world(world)
        -- A streamed level retains its package UWorld as its outer, while its
        -- ULevel.OwningWorld points at the world in which it is playing. Mission
        -- actors and cinematic/animation objects can therefore report different
        -- GetWorld results within the same live mission.
        local seen = {}
        for _ = 1, 8 do
            local address = world:GetAddress()
            if seen[address] then return nil, "cyclic level ownership" end
            seen[address] = true
            local level = read(world, "PersistentLevel")
            local owner = valid(level) and read(level, "OwningWorld") or nil
            if not valid(owner) then return nil, "level owning world unavailable: " .. name(world) end
            if owner:GetAddress() == address then return world end
            world = owner
        end
        return nil, "level ownership depth exceeded"
    end

    function self:owns(object)
        if not self:is_active() then return false, "mission inactive" end
        if not valid(object) then return false, "invalid object" end
        local ok, result, reason = pcall(function()
            local world, mission_world = object:GetWorld(), self.actor:GetWorld()
            if not valid(world) then return false, "object GetWorld returned invalid" end
            if not valid(mission_world) then return false, "mission GetWorld returned invalid" end
            local world_error, mission_error
            world, world_error = owning_world(world)
            mission_world, mission_error = owning_world(mission_world)
            if not world then return false, world_error end
            if not mission_world then return false, mission_error end
            if world:GetAddress() ~= mission_world:GetAddress() then
                return false, "world mismatch: " .. name(world) .. " / mission: " .. name(mission_world)
            end
            return true, "same owning world"
        end)
        if not ok then return false, "world lookup failed: " .. tostring(result) end
        return result == true, reason
    end

    function self:observe(actor, reason, restart)
        if not is_mission(actor) then return end
        local actor_name = name(actor)
        if not restart and self.actor_name == actor_name and self:is_active() then return end
        self:stop(reason)
        self.actor, self.actor_name = actor, actor_name
        local generation = self.generation

        -- The Blueprint override need not call its native parent on save load.
        -- Retry installation on each real mission event, once its class exists.
        local ok, err = pcall(function()
            runtime:register_hook(SAVE_HOOK, function(Context)
                self:observe(unwrap(Context), "mission save loaded", true)
            end)
        end)
        if not ok then options.log("Mission save hook unavailable | %s", tostring(err)) end

        local function attempt(index)
            local previous = index > 1 and READY_MS[index - 1] or 0
            actions:schedule_after("mission_readiness", READY_MS[index] - previous, function()
                if generation ~= self.generation or not runtime.alive then return end
                if not valid(actor) then self:stop("mission destroyed during readiness"); return end
                if ready(actor) then
                    self.active = true
                    options.on_start(reason)
                elseif index < #READY_MS then
                    attempt(index + 1)
                else
                    options.log("Mission readiness timed out | ready=%s | status=%s | ending=%s | %s",
                        tostring(read(actor, "bIsMissionActorReady")),
                        tostring(read(actor, "MissionStatus")),
                        tostring(read(actor, "bIsMissionEnding")), actor_name)
                end
            end)
        end
        attempt(1)
    end

    function self:install()
        local function observe(Context)
            self:observe(unwrap(Context), "mission lifecycle event")
        end
        for _, path in ipairs({
            CLASS .. ":HandleMapBeginPlayReceived",
            CLASS .. ":EncounterStarted",
        }) do
            -- Native hooks: inspect readiness after the game updates its state.
            runtime:register_hook(path, function() end, observe)
        end
        runtime:register_hook(CLASS .. ":SetIsMissionEnding", function(Context, Ending)
            if self.actor_name and name(unwrap(Context)) == self.actor_name
                and unwrap(Ending) == true then self:stop("mission ending") end
        end)
        runtime:bind("lifecycle:load-map", RegisterLoadMapPreHook, function()
            self:stop("map changing")
            -- Return nil: never override the engine's LoadMap result.
        end)
        runtime:bind("lifecycle:end-play", RegisterEndPlayPreHook, function(Context)
            if self.actor_name and name(unwrap(Context)) == self.actor_name then
                self:stop("mission actor end play")
            end
        end)
        runtime:bind("notify:mission", function(dispatch)
            NotifyOnNewObject(CLASS, dispatch)
        end, function(actor)
            self:observe(actor, "mission actor created")
        end)

        -- One catch-up scan on the game thread supports a reload into an
        -- already-running mission. No montage scan or permanent polling here.
        local objects = FindAllOf("BRGameMissionActor")
        local candidate
        for _, actor in pairs(objects or {}) do
            if is_mission(actor) then
                candidate = candidate or actor
                if ready(actor) then candidate = actor; break end
            end
        end
        -- A reload can also land between construction and readiness, after
        -- the new-object event was missed. Give that instance bounded checks.
        if candidate then self:observe(candidate, "existing mission") end
    end

    return self
end

return M
