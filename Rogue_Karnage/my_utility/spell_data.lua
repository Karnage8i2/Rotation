local spell_data = {
    -- Core spells
    heartseeker = {
        spell_id = 363402,
        buff_ids = {
            crit = 363403,
            vulnerable = 363404
        }
    },
    smoke_grenade = {
        spell_id = 356162,
        buff_ids = {
            effect = 356163
        }
    },
    shadow_clone = {
        spell_id = 357628,
        buff_ids = {
            effect = 357629
        }
    },
    cold_imbuement = {
        spell_id = 359246,
        buff_ids = {
            effect = 359247
        }
    },
    blade_shift = {
        spell_id = 399111,
    },
    concealment = {
        spell_id = 794965,
        buff_ids = {
            stealth = 794966
        }
    },
    shadow_imbuement = {
        spell_id = 380288,
        buff_ids = {
            effect = 380289
        }
    },
    shadow_step = {
        spell_id = 355606,
    },
    dance_of_knives = {
        spell_id = 1690398,
    },
    puncture = {
        spell_id = 364877,
    },
    rain_of_arrows = {
        spell_id = 400232,
    },
    forcefull_arrow = {
        spell_id = 416272,
    },
    invigorating_strike = {
        spell_id = 416057,
    },
    twisting_blade = {
        spell_id = 398258,
    },
    barrage = {
        spell_id = 439762,
    },
    rapid_fire = {
        spell_id = 355926,
    },
    flurry = {
        spell_id = 358339,
    },
    penetrating_shot = {
        spell_id = 377137,
    },
    poison_trap = {
        spell_id = 416528,
        buff_ids = {
            effect = 416529
        }
    },
    dark_shroud = {
        spell_id = 786381,
        buff_ids = {
            effect = 786383
        }
    },
    poison_imbuement = {
        spell_id = 358508,
        buff_ids = {
            effect = 358509
        }
    },
    death_trap = {
        spell_id = 421161,
    },
    dash = {
        spell_id = 358761,
    },
    caltrop = {
        spell_id = 389667,
    },
    
    -- Class mechanic buffs
    inner_sight = {
        buff_id = 391682
    },
    
    -- Enemy effects
    enemies = {
        damage_resistance = {
            spell_id = 367225,
            buff_ids = {
                provider = 367226,
                receiver = 367227
            }
        },
        vulnerable = {
            buff_id = 298962
        },
        crowd_control = {
            buff_id = 39809
        },
        frozen = {
            buff_id = 290962
        },
        trapped = {
            buff_id = 1285259
        }
    },
    
    -- System buffs
    in_combat_area = {
        spell_id = 24312,
        buff_id = 24313
    },
    evade = {
        spell_id = 337031
    }
}

return spell_data