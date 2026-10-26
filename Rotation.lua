local ADDON_NAME, ns = ...

-- Registry of rotation definitions. Rotation files call ns.Rotation{ class=, spec=, reminders=, preparation=, highprio=, rotations={ single=, multi=, aoe= },
-- defensives=, utility=, trackers=, offensives= (see Slots.lua),
-- consumables={ raid flasks/elixirs to remind about, see Common.lua } };
-- omitting spec makes the rotation apply to every spec of that class.
ns.rotations = {}

function ns.Rotation(def)
    ns.rotations[def.class .. ":" .. (def.spec or "*")] = def
end

-- The rotation for the detected class and spec (see Class.lua), or nil.
function ns.GetRotation()
    if not ns.class then return end
    return ns.rotations[ns.class .. ":" .. tostring(ns.specIndex)] or ns.rotations[ns.class .. ":*"]
end

-- Entries name spells by name or by spell ID.
function ns.SpellName(spell)
    if type(spell) == "number" then return (GetSpellInfo(spell)) end
    return spell
end
