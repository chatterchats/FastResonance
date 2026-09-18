-- Fast Resonance target registry.
--
-- MXM is intentionally grouped by ability rather than presentation layer:
--
--   Resonance Transfer
--     enabled: resonance_transfer_enabled
--     speed:   resonance_transfer_speed
--
--   Shared Suffering
--     enabled: shared_suffering_enabled
--     speed:   shared_suffering_speed
--
--   Unnatural Resilience
--     enabled: unnatural_resilience_enabled
--     speed:   unnatural_resilience_speed
--
-- Individual body/camera/facial/confirm pieces are implementation details and
-- use the ability-level setting automatically.

return {
    montages = {
        {
            kind = "unnatural-resilience-body",
            token = "A_2HRifle_Coil_Brute_Tenacity_Start",
            enabled_key = "unnatural_resilience_enabled",
            speed_key = "unnatural_resilience_speed",
        },
        -- Captured from SM_Resonate: target these specific body assets without
        -- broadening the match to unrelated Coil or generic Resonance assets.
        {
            kind = "resonate-captain-body",
            token = "A_1HPistol_Coil_Captain_Resonance",
            enabled_key = "resonance_transfer_enabled",
            speed_key = "resonance_transfer_speed",
        },
        {
            kind = "transfer-nonsurge-body",
            token = "A_2HRifle_Coil_PlagueTransfer_NonSurge",
            enabled_key = "resonance_transfer_enabled",
            speed_key = "resonance_transfer_speed",
        },
        {
            kind = "transfer-body",
            token = "Coil_PlagueTransfer_Surge",
            enabled_key = "resonance_transfer_enabled",
            speed_key = "resonance_transfer_speed",
        },
        {
            kind = "surge-face",
            token = "brk_combat_i_do_surge_",
            enabled_key = "resonance_transfer_enabled",
            speed_key = "resonance_transfer_speed",
        },
        {
            kind = "shared-suffering-body",
            token = "A_1HMelee_Guardian_SharedSuffering",
            enabled_key = "shared_suffering_enabled",
            speed_key = "shared_suffering_speed",
        },
    },

    level_sequences = {
        -- Match whole captured state-machine instance names, not generic asset
        -- names. This covers each choreography stage only inside these abilities.
        {
            kind = "resonate-camera",
            context_pattern = "%.SM_Resonate_C_%d+%.",
            enabled_key = "resonance_transfer_enabled",
            speed_key = "resonance_transfer_speed",
        },
        {
            kind = "unnatural-resilience-camera",
            context_pattern = "%.SM_Tenacity_C_%d+%.",
            enabled_key = "unnatural_resilience_enabled",
            speed_key = "unnatural_resilience_speed",
        },
        {
            kind = "surge-camera",
            token = "LS_AG_PlagueTransfer_Surge_",
            enabled_key = "resonance_transfer_enabled",
            speed_key = "resonance_transfer_speed",
        },
        {
            kind = "shared-suffering-camera",
            token = "LS_AG_SharedSuffering",
            enabled_key = "shared_suffering_enabled",
            speed_key = "shared_suffering_speed",
        },
        {
            kind = "shared-suffering-confirm",
            token = "LS_AG_Humanoid_2HRifle_Confirm_Crouching",
            context_token = "SM_SharedSuffering_C_",
            enabled_key = "shared_suffering_enabled",
            speed_key = "shared_suffering_speed",
        },
    },
}
