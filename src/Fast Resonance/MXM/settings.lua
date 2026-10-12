local function ability(key, name, desc)
    return { key = key, type = "bool", name = name, default = true, desc = desc }
end

return {
    id      = "FastResonance",
    name    = "Fast Resonance",
    version = "1.0.5",
    description = "Speeds up Coil ability presentations.",

    settings = {
        { key = "speed", type = "number",
          name = "Speed", default = 4.0,
          min = 0.25, max = 8.0, step = 0.25,
          desc = "Applies to every enabled ability below. 1.0x is vanilla; 4.0x is the recommended default." },

        { type = "header", name = "Abilities" },

        ability("resonance_transfer_enabled", "Resonance Transfer",
            "Resonate and plague transfer: the bridge between units, body animation and camera."),
        ability("shared_suffering_enabled", "Shared Suffering",
            "The Guardian's link, its Confirm shot and end hold, and the damage redirect that takes the camera."),
        ability("unnatural_resilience_enabled", "Unnatural Resilience",
            "The Brute's hold, body animation and camera."),
        ability("tenacity_heal_enabled", "Tenacity Heal", "The Brute's heal presentation."),
        ability("miasma_enabled", "Miasma", "The Captain's Miasma presentation."),
        ability("plague_surge_enabled", "Plague Surge", "Surging and plague stack gain presentations."),
        ability("scream_enabled", "Scream", "The Brute's Scream presentation."),
        ability("devour_enabled", "Devour", "The Seer's Devour presentation."),
        ability("bind_enabled", "Bind", "The Seer's Bind and its release."),
        ability("cloak_enabled", "Cloak", "The Striker's cloak, reaction cloak and decloak presentations."),
        ability("death_explosion_enabled", "Death Explosion", "The plague explosion when a Coil unit dies."),
        ability("life_beyond_death_enabled", "Life Beyond Death", "The Life Beyond Death presentation."),
        ability("melee_strike_enabled", "Melee Strike", "Coil melee strike presentations."),
    },
}
