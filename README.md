# Combat Movement (Battle Brothers mod)

Rewards characters who move on their own before they strike.

- A character that **walks at least one hex on its own** gets the status effect **Moving**.
- Every walked hex adds **+10 % damage** (adjustable, 5–20 %).
- The bonus stops growing at **3 hexes** (adjustable, 1–10), so the default maximum is +30 %.
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
| Damage per hex (%) | 5–20 | 10 |
| Hexes for maximum bonus | 1–10 | 3 |

The values are saved in your profile and apply right away, also to an effect that is already active.

## How it works

The engine calls `actor.onMovementStep` for every hex of a path the character walks (that is where it charges AP for movement). Skills and knockbacks move actors with `teleport()` or `switchEntities()`, which never call it. The mod counts those steps and adds the hexes to the effect when the movement finishes. As an extra guard, steps taken while a skill is being used are ignored.

The skill hook on `skill.use` ends the effect when a skill is really used (not for free). The effect then hides and keeps boosting only that skill until the next skill use or the end of the turn, so attacks that hit after the skill call returns (Lunge and similar) still get the bonus.

## Compatibility

- Overwrites no vanilla files. Hooks: `actor.onMovementStart`, `onMovementStep`, `onMovementUndo`, `onMovementFinish` and `skill.use`. Each one calls the original.
- The effect is not serialized and is removed after each battle, so the mod can be added to or removed from existing savegames.

## Installation

Zip the contents of this folder (the `scripts` and `gfx` directories at the zip root) as
`mod_combat_movement.zip` and put it into `Battle Brothers/data`.

```powershell
Compress-Archive -Path scripts, gfx -DestinationPath "..\..\..\data\mod_combat_movement.zip" -Force
```

## Files

| Path | Purpose |
| --- | --- |
| `scripts/!mods_preload/mod_combat_movement.nut` | Registers the mod with Modern Hooks, adds the MSU settings and the movement and skill hooks |
| `scripts/skills/effects/mod_combat_movement_effect.nut` | The Moving status effect |
| `gfx/skills/mod_combat_movement_moving.png` | Status effect icon |
