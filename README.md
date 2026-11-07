# Combat Movement (Battle Brothers mod)

Rewards characters who move on their own before they strike.

- A character that **walks at least one hex on its own** gets the status effect **Moving**.
- The damage bonus grows with every walked hex, faster the more hexes:
  **bonus % = hexes × base bonus + hexes² × dynamic bonus** (both default 5, adjustable 0–10).
- The bonus stops growing at **3 hexes** (adjustable, 1–10). With the defaults that is +10 % after 1 hex, +30 % after 2 and +60 % after 3.
- **Thrusting attacks and Knock Back cost less AP:** (counted hexes − 1), at least 1 AP. Counted hexes stop at the maximum, so with the default of 3 it is at most −2 AP. Thrusting attacks are Thrust (spears), Stab and Puncture (daggers), Impale (pikes), Prong (pitchfork), Rupture (spetum), Deathblow (qatal dagger) and the Estoc stab.
- **Knock Back (shields) with momentum:**
  - on a hit the target is **staggered** (1+ hexes) and also **stunned** (2+ hexes, unless immune to stun),
  - it is pushed **counted hexes** tiles instead of 1 (walk 3 hexes → pushed 3 tiles, never more than the maximum). The push stops early at an occupied tile, the map edge or a height step of more than 1 level.
- Hexes add up across several moves while the effect lasts.
- The effect **carries over into the next round**.
- The effect is **lost when the character uses Wait or any skill**. The skill that ends it still gets the bonus (move, then attack). Skills used for free, such as attacks of opportunity or Riposte, do not end it.
- Only voluntary walking counts. Being knocked back, pulled or swapped does not, and neither does movement from skills such as Footwork, Rotation or Lunge.
- Works for every character, player or AI.

## Requirements

- Battle Brothers (vanilla, all DLCs optional)
- [Modern Hooks](https://www.nexusmods.com/battlebrothers/mods/685)
- [MSU](https://www.nexusmods.com/battlebrothers/mods/479) is optional. With MSU the values can be changed in the mod settings; without it the defaults are used.

## Mod settings (MSU)

Open **Mod Settings → Combat Movement → General**:

| Setting | Range | Default |
| --- | --- | --- |
| Base bonus (%) | 0–10 | 5 |
| Dynamic bonus (%) | 0–10 | 5 |
| Hexes for maximum bonus | 1–10 | 3 |

The values are saved in your profile and apply right away, also to an effect that is already active.

## How it works

The engine calls `actor.onMovementStep` for every hex of a path the character walks (that is where it charges AP for movement). Skills and knockbacks move actors with `teleport()` or `switchEntities()`, which never call it. The mod adds the effect, or one more hex to it, right in that step. As an extra guard, steps taken while a skill is being used are ignored.

The effect uses the icon of the vanilla Pathfinder perk (`ui/perks/perk_23.png`). The game has no small battlefield icon for that perk, so the effect shows only in the character's status effects.

The mod writes what it does into `log.html` (lines starting with `CombatMovement:`). Set `IsLogging = false` in `mod_combat_movement.nut` to turn this off.

The skill hook on `skill.use` ends the effect when a skill is really used (not for free). The effect then hides and keeps boosting only that skill until the next skill use or the end of the turn, so attacks that hit after the skill call returns (Lunge and similar) still get the bonus.

## Compatibility

- Overwrites no vanilla files. Hooks: `actor.onMovementStep`, `onMovementUndo`, `onTurnStart`, `skill.use`, `skill.getActionPointCost` and `knock_back.onUse`. Each one calls the original, except `knock_back.onUse` while the character has momentum: then the mod runs its own copy of the vanilla Knock Back (hit roll, fatigue, removing Shieldwall/Spearwall/Riposte, fall damage) with the extra stagger, stun and push.
- The thrusting skills are listed in `MomentumSkillIDs` (and `MomentumClassNames`) in `mod_combat_movement.nut`.
- The effect is not serialized and is removed after each battle, so the mod can be added to or removed from existing savegames.

## Installation

Zip the `scripts` directory of this folder (at the zip root) as
`mod_combat_movement.zip` and put it into `Battle Brothers/data`.

```powershell
Compress-Archive -Path scripts -DestinationPath "..\..\..\data\mod_combat_movement.zip" -Force
```

## Files

| Path | Purpose |
| --- | --- |
| `scripts/!mods_preload/mod_combat_movement.nut` | Registers the mod with Modern Hooks, adds the MSU settings and the movement and skill hooks |
| `scripts/skills/effects/mod_combat_movement_effect.nut` | The Moving status effect |
