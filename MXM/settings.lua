return {
    id      = "FastResonance",
    name    = "Fast Resonance",
    version = "1.0.1",
    description = "Speeds selected Coil Resonance ability presentations.",

    settings = {
        { type = "header", name = "Resonance Transfer" },

        { key = "resonance_transfer_enabled", type = "bool",
          name = "Enable Resonance Transfer", default = true,
          desc = "Speeds the Resonance transfer body animation, camera choreography, and recipient reaction together." },

        { key = "resonance_transfer_speed", type = "number",
          name = "Multiplier", default = 4.0,
          min = 0.25, max = 8.0, step = 0.25,
          desc = "1.0x is vanilla. 4.0x is the recommended default." },

        { type = "header", name = "Shared Suffering" },

        { key = "shared_suffering_enabled", type = "bool",
          name = "Enable Shared Suffering", default = true,
          desc = "Speeds Shared Suffering's body animation, camera, Confirm choreography, and final presentation delay together." },

        { key = "shared_suffering_speed", type = "number",
          name = "Multiplier", default = 4.0,
          min = 0.25, max = 8.0, step = 0.25,
          desc = "1.0x is vanilla. 4.0x is the recommended default." },
    },
}
