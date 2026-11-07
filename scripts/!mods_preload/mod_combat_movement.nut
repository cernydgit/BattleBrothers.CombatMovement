::ModCombatMovement <- {
	ID = "mod_combat_movement",
	Name = "Combat Movement",
	Version = "1.1.0",
	EffectID = "effects.mod_combat_movement_moving",
	EffectScript = "scripts/skills/effects/mod_combat_movement_effect",
	// Used when MSU is not installed, and as the defaults of the mod settings
	// Damage bonus in % = hexes * BaseBonus + hexes^2 * DynamicBonus
	Defaults = {
		BaseBonus = 5,
		DynamicBonus = 5,
		MaxHexes = 3
	},
	MSUMod = null,
	// Writes what the mod does into log.html (gained, walked hexes, ended)
	IsLogging = true,
	// > 0 while a skill is being used, so movement caused by a skill never counts
	SkillsInUse = 0
};

// Current value from the MSU mod settings, or the default without MSU
::ModCombatMovement.getSetting <- function( _settingID )
{
	if (::ModCombatMovement.MSUMod != null && ::ModCombatMovement.MSUMod.ModSettings.hasSetting(_settingID))
	{
		return ::ModCombatMovement.MSUMod.ModSettings.getSetting(_settingID).getValue().tointeger();
	}

	return ::ModCombatMovement.Defaults[_settingID];
};

::ModCombatMovement.log <- function( _text )
{
	if (::ModCombatMovement.IsLogging)
	{
		::logInfo("CombatMovement: " + _text);
	}
};

::ModCombatMovement.Mod <- ::Hooks.register(::ModCombatMovement.ID, ::ModCombatMovement.Version, ::ModCombatMovement.Name);
::ModCombatMovement.Mod.require("mod_modern_hooks");

// ">mod_msu" only sets load order; MSU is optional
::ModCombatMovement.Mod.queue(">mod_msu", function()
{
	if (::Hooks.hasMod("mod_msu"))
	{
		::ModCombatMovement.MSUMod = ::MSU.Class.Mod(::ModCombatMovement.ID, ::ModCombatMovement.Version, ::ModCombatMovement.Name);

		local page = ::ModCombatMovement.MSUMod.ModSettings.addPage("General");
		page.addRangeSetting("BaseBonus", ::ModCombatMovement.Defaults.BaseBonus, 0, 10, 1, "Base bonus (%)", "Damage bonus for every walked hex. Total bonus = hexes x Base bonus + hexes^2 x Dynamic bonus.");
		page.addRangeSetting("DynamicBonus", ::ModCombatMovement.Defaults.DynamicBonus, 0, 10, 1, "Dynamic bonus (%)", "Damage bonus multiplied by the square of the walked hexes. Total bonus = hexes x Base bonus + hexes^2 x Dynamic bonus.");
		page.addRangeSetting("MaxHexes", ::ModCombatMovement.Defaults.MaxHexes, 1, 10, 1, "Hexes for maximum bonus", "Number of walked hexes at which the damage bonus stops growing.");
	}

	// Voluntary movement is the only movement that goes through the navigator
	// path by path: the engine calls onMovementStep for every hex and charges
	// its AP there. Skills (Footwork, Rotation, Lunge, ...) and knockbacks move
	// actors with teleport() or switchEntities(), which never call onMovementStep.
	// The effect is updated right in onMovementStep, so it does not depend on
	// the order in which the engine calls the other movement callbacks.
	::ModCombatMovement.Mod.hook("scripts/entity/tactical/actor", function( q )
	{
		q.onMovementStep = @(__original) function( _tile, _levelDifference )
		{
			local ret = __original(_tile, _levelDifference);

			if (!ret || !this.isAlive())
			{
				return ret;
			}

			if (::ModCombatMovement.SkillsInUse != 0 || this.m.CurrentMovementType != ::Const.Tactical.MovementType.Default)
			{
				::ModCombatMovement.log(this.getName() + " moved a hex, not counted (skill in use: " + ::ModCombatMovement.SkillsInUse + ", movement type: " + this.m.CurrentMovementType + ")");
				return ret;
			}

			local effect = this.getSkills().getSkillByID(::ModCombatMovement.EffectID);

			if (effect == null)
			{
				effect = ::new(::ModCombatMovement.EffectScript);
				this.getSkills().add(effect);
				::ModCombatMovement.log(this.getName() + " gained Moving");
			}
			else if (effect.isGarbage())
			{
				// Removed earlier this frame and not collected yet
				effect.revive();
			}

			effect.addHexes(1);
			::ModCombatMovement.log(this.getName() + " walked a hex, Moving " + effect.m.Hexes + " hex(es), +" + effect.getBonusPercent() + "% damage");

			return ret;
		}

		q.onMovementUndo = @(__original) function( _tile, _levelDifference )
		{
			local effect = this.getSkills().getSkillByID(::ModCombatMovement.EffectID);

			if (effect != null && !effect.isGarbage() && !effect.isConsumed())
			{
				effect.removeHexes(1);
			}

			return __original(_tile, _levelDifference);
		}

		q.onTurnStart = @(__original) function()
		{
			// Safety net: a skill use can never span turns
			::ModCombatMovement.SkillsInUse = 0;
			return __original();
		}
	});

	// Using any skill (not for free) ends the Moving effect. The effect stays
	// on that one skill until it is fully resolved, so attacks that land after
	// use() returns (e.g. Lunge) still get the bonus.
	::ModCombatMovement.Mod.hook("scripts/skills/skill", function( q )
	{
		q.use = @(__original) function( _targetTile, _forFree = false )
		{
			local effect = null;

			if (!_forFree && this.getContainer() != null)
			{
				effect = this.getContainer().getSkillByID(::ModCombatMovement.EffectID);

				// Left over from the previously used skill
				if (effect != null && effect.isConsumed())
				{
					effect.removeSelf();
					effect = null;
				}
			}

			local skillCounter = ::Const.SkillCounter;
			++::ModCombatMovement.SkillsInUse;

			local ret;

			try
			{
				ret = __original(_targetTile, _forFree);
			}
			catch( e )
			{
				--::ModCombatMovement.SkillsInUse;
				throw e;
			}

			--::ModCombatMovement.SkillsInUse;

			// SkillCounter only changes when the skill was really used (not for free)
			if (effect != null && !effect.isGarbage() && ::Const.SkillCounter != skillCounter)
			{
				effect.consume(this);
				::ModCombatMovement.log("Moving ended by " + this.getID());
			}

			return ret;
		}
	});
});
