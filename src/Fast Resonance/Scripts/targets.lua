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
-- Individual body/camera/facial/confirm pieces are implementation details and
-- use the ability-level setting automatically.

return {
    montages = {
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
