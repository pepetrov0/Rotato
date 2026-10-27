local ADDON_NAME, ns = ...

-- Marksmanship hunter. Conditions are functions of `c`, the condition API in Engine.lua;
-- c.mana is a percentage. The entry fields for the side slots are described in Slots.lua.

-- Every aspect, so the tracker shows whichever one is active.
local ASPECTS = {
    "Aspect of the Dragonhawk", "Aspect of the Wild", "Aspect of the Viper", "Aspect of the Hawk",
    "Aspect of the Beast", "Aspect of the Monkey", "Aspect of the Pack", "Aspect of the Cheetah",
}

-- Dragonhawk and Wild are interchangeable for damage, so being in either means "no need to swap".
-- Which one to suggest is the dpsAspect variant below.
local DPS_ASPECTS = { "Aspect of the Dragonhawk", "Aspect of the Wild" }

-- Misdirection needs someone to hand the threat to
local function NoMisdirectionTarget(c) return c.inGroup and not UnitExists("focus") end

ns.Rotation{
    class = "HUNTER",
    spec = 2, -- Marksmanship

    -- Which damage aspect to go back to after Viper is whichever one was used last, which can only
    -- be known from what the player casts (see Rotation.lua). Casting Viper changes nothing here.
    variants = {
        dpsAspect = {
            default = "dragonhawk",
            dragonhawk = { "Aspect of the Dragonhawk" },
            wild = { "Aspect of the Wild" },
        },
    },

    -- Out of combat with no hostile target, most important first. Trueshot Aura only has to be
    -- recast after a death, which makes it easy to forget, so it leads.
    reminders = {
        { "Trueshot Aura", when = function(c) return not c.buff("Trueshot Aura").up end },

        -- the pet is gone or dead before it is merely hurt or hungry
        { "Revive Pet", when = function(c) return c.pet.dead end },
        { "Call Pet", when = function(c) return c.pet.missing end },
        { "Feed Pet", when = function(c) return c.pet.hungry end },
        { "Mend Pet", when = function(c)
            return c.pet.exists and c.pet.hp < 100 and not c.pet.buff("Mend Pet").up
        end },

        -- Viper regenerates mana, which is what the downtime between fights is for
        { "Aspect of the Viper", when = function(c) return not c.buff("Aspect of the Viper").up end },
    },

    -- Out of combat, only worth doing once there is something to pull. Hunter's Mark is not a
    -- reminder because without a target it cannot be cast at all.
    preparation = {
        { "Hunter's Mark", when = function(c)
            return c.target.hostile and not c.debuff("Hunter's Mark", { any = true }).up
        end },
    },

    -- Checked before the rotation, in combat or with a hostile target.
    highprio = {
        -- once per death, see the reminder above; kept here too in case it fell off mid-fight
        { "Trueshot Aura", when = function(c) return not c.buff("Trueshot Aura").up end },

        -- Top priority: an enrage can kill a tank outright, so removing it beats any damage
        { "Tranquilizing Shot", when = function(c) return c.target.hasBuffType("Enrage", "Magic") end },

        { "Mend Pet", when = function(c)
            return c.combat and c.pet.exists and c.pet.hp < 50 and not c.pet.buff("Mend Pet").up
        end },

        -- Viper below 10% mana to recover, the last damage aspect above 80% to get the damage back. The gap
        -- between the two stops it from flip-flopping around a single threshold.
        { "Aspect of the Viper", when = function(c)
            return c.mana < 10 and not c.buff("Aspect of the Viper").up
        end },
        { variant = "dpsAspect", when = function(c)
            return c.mana > 80 and not c.anyBuff(DPS_ASPECTS).up
        end },
        -- Last, because it is upkeep rather than damage. A boss is the only target worth a mid-fight
        -- refresh; anything hostile is marked before a pull (see preparation).
        { "Hunter's Mark", when = function(c)
            return c.target.boss and not c.debuff("Hunter's Mark", { any = true }).up
        end },
    },

    rotations = {
        single = {
            { "Kill Shot", when = function(c) return c.target.hostile and c.target.hp < 20 end },
            -- permanent upkeep: Chimera Shot refreshes the sting and turns it into instant damage
            { "Serpent Sting", when = function(c)
                return c.target.hostile and not c.debuff("Serpent Sting").up
            end },
            { "Aimed Shot" },
            { "Chimera Shot" },
            { "Steady Shot" },
        },

        -- Multi-Shot is only in this list and Volley only in the aoe one, so casting either selects
        -- that rotation (see Mode.lua).
        multi = {
            { "Kill Shot", when = function(c) return c.target.hostile and c.target.hp < 20 end },
            -- permanent upkeep: Chimera Shot refreshes the sting and turns it into instant damage
            { "Serpent Sting", when = function(c)
                return c.target.hostile and not c.debuff("Serpent Sting").up
            end },
            { "Multi-Shot" },
            { "Chimera Shot" },
            { "Steady Shot" },
        },

        aoe = {
            { "Volley" },
        },
    },

    trackers = {
        { buff = ASPECTS },
        { debuff = "Hunter's Mark", any = true }, -- anyone's mark is as good as yours
        { debuff = "Serpent Sting" },             -- only yours counts, it is what Chimera Shot refreshes
        { targetBuffType = { "Magic", "Enrage" } }, -- something to Tranquilizing Shot off the target
    },

    defensives = {
        { spell = "Feign Death", buff = "Feign Death" },
        { spell = "Disengage" },
        { spell = "Deterrence", buff = "Deterrence" },
    },

    utility = {
        -- Recommended when Chimera Shot is ready. Pointless in a group with no focus to misdirect to,
        -- so it is grayed out then, and the recommendation is withheld so it never flashes while
        -- grayed out.
        { spell = "Misdirection", buff = "Misdirection",
          discourage = NoMisdirectionTarget,
          recommend = function(c)
              return c.ready("Misdirection") and c.ready("Chimera Shot") and not c.buff("Misdirection").up
                  and not NoMisdirectionTarget(c)
          end },

        -- Readiness resets the others, so it is only worth its long cooldown once they are far from ready
        { spell = "Readiness", recommend = function(c)
            return c.ready("Readiness") and (c.cd("Misdirection") > 15 or c.cd("Rapid Fire") > 15)
        end },

        -- These only show when needed; they are also reminders, this is the slot for acting on them
        { spell = "Call Pet", when = function(c) return c.pet.missing end, recommend = function() return true end },
        { spell = "Feed Pet", when = function(c) return c.pet.hungry end,
          recommend = function(c) return not c.combat end },
        { spell = "Revive Pet", when = function(c) return c.pet.dead end },
    },

    offensives = {
        -- always worth using on cooldown
        { spell = "Rapid Fire", buff = "Rapid Fire", recommend = function(c) return c.ready("Rapid Fire") end },
    },
}
