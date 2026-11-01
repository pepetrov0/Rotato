# Rotato

A World of Warcraft 3.3.5a (Wrath of the Lich King) addon.

## Install

Place this folder in `Interface/AddOns/Rotato`, then enable it at the character select screen.

## Usage

`/rotato` (or `/rota`) on its own lists the commands:

| Command | What it does |
|---|---|
| `/rotato unlock` | Move the frame (left-drag) and open its options (right-click) |
| `/rotato lock` | Make the frame click-through again |
| `/rotato reset` | Move the frame back to its default position |
| `/rotato log` | Turn the chat log of automatic changes on or off (off by default) |
| `/rotato rotation` | Choose the rotation (opens the picker right away) |
| `/rotato rotation reset` | Forget this talent group's choice, so the picker asks again |

From level 10, Rotato asks which rotation you want the next time you open your spellbook (P), and
keeps asking there until you pick one, or "My own way" for none. It never pops up
in the world or in combat.
| `/rotato debug` | Print why the current suggestion is what it is |

Options (size, icons per row, font, text sizes, transparency, chat log) are in the frame's
right-click menu: `/rotato unlock`, right-click the frame, then `/rotato lock` when done.

## Reading the frame

The big icon in the middle is what to press next. Its text says why:

| Text | Meaning |
|---|---|
| *(none)* | Press it now |
| Next | Press it as soon as the global cooldown or your current cast ends |
| Cooldown | The best spell is still on cooldown; the sweep shows how long |
| Waiting | The spell is not usable yet (not enough mana, rage...); the icon is grayed out |
| Reminder | Out of combat: a buff, seal, poison or pet is missing |

The small icons sit in four rows around it:

```
 utility    | next  | trackers
 defensives | spell | offensives
```

- **Utility, defensives, offensives**: your cooldowns, and the buff or debuff they put up.
- **Trackers**: auras that should always be there (seals, weapon enchants, Replenishment...). They
  only exist to catch what is missing, so they show only auras and read a little differently.

### Borders

| Border | In utility, defensives, offensives | In trackers |
|---|---|---|
| None | Nothing to note | The aura is up and healthy |
| Red | A debuff on you or a buff on your target: something bad for you | The aura is missing or about to run out, or a dispellable aura is on the target or on your heal target |
| Green | Active and good for you: a buff on you or your debuff on the target | - |
| Flashing white | Recommended right now | - |
| Blue | Blocking: an aura stops one of your abilities while it runs (Weakened Soul...) | Same |

Any border flashes when its aura has less than 5 seconds left. An icon that is grayed out and
faded means using it now is pointless (for example Divine Shield during Forbearance).

## Todo

- Death Knight
  - [x] Blood
  - [ ] Frost
  - [ ] Unholy
- Druid
  - [ ] Balance
  - [ ] Feral
  - [x] Restoration
- Hunter
  - [ ] Beast Mastery
  - [x] Marksmanship
  - [ ] Survival
- Mage
  - [ ] Arcane
  - [ ] Fire
  - [ ] Frost
- Paladin
  - [x] Holy
  - [x] Protection
  - [x] Retribution
- Priest
  - [x] Discipline
  - [ ] Holy
  - [ ] Shadow
- Rogue
  - [ ] Assassination
  - [x] Combat
  - [ ] Subtlety
- Shaman
  - [ ] Elemental
  - [ ] Enhancement
  - [x] Restoration
- Warlock
  - [ ] Affliction
  - [ ] Demonology
  - [ ] Destruction
- Warrior
  - [ ] Arms
  - [ ] Fury
  - [ ] Protection
