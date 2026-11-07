::ModCombatMovement <- {
	ID = "mod_combat_movement",
	Name = "Combat Movement",
	Version = "1.0.0",
	EffectID = "effects.mod_combat_movement_moving",
	EffectScript = "scripts/skills/effects/mod_combat_movement_effect",
	// Used when MSU is not installed, and as the defaults of the mod settings
	Defaults = {
		DamagePerHex = 10,
		MaxHexes = 3
	},
	MSUMod = null,
	// Actor ID -> hexes walked during the movement that is in progress
	PendingHexes = {},
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

::ModCombatMovement.Mod <- ::Hooks.register(::ModCombatMovement.ID, ::ModCombatMovement.Version, ::ModCombatMovement.Name);
::ModCombatMovement.Mod.require("mod_modern_hooks");

// ">mod_msu" only sets load order; MSU is optional
::ModCombatMovement.Mod.queue(">mod_msu", function()
{
	if (::Hooks.hasMod("mod_msu"))
	{
		::ModCombatMovement.MSUMod = ::MSU.Class.Mod(::ModCombatMovement.ID, ::ModCombatMovement.Version, ::ModCombatMovement.Name);

		local page = ::ModCombatMovement.MSUMod.ModSettings.addPage("General");
		page.addRangeSetting("DamagePerHex", ::ModCombatMovement.Defaults.DamagePerHex, 5, 20, 1, "Damage per hex (%)", "Damage bonus a moving character gets for every hex it walked.");
		page.addRangeSetting("MaxHexes", ::ModCombatMovement.Defaults.MaxHexes, 1, 10, 1, "Hexes for maximum bonus", "Number of walked hexes at which the damage bonus stops growing.");
	}

	// Voluntary movement is the only movement that goes through the navigator
	// path by path: the engine calls onMovementStep for every hex and charges
	// its AP there. Skills (Footwork, Rotation, Lunge, ...) and knockbacks move
	// actors with teleport() or switchEntities(), which never call onMovementStep.
	::ModCombatMovement.Mod.hook("scripts/entity/tactical/actor", function( q )
	{
		q.onMovementStart = @(__original) function( _tile, _numTiles )
		{
			::ModCombatMovement.PendingHexes[this.getID()] <- 0;
			return __original(_tile, _numTiles);
		}

		q.onMovementStep = @(__original) function( _tile, _levelDifference )
		{
			local ret = __original(_tile, _levelDifference);

			if (ret && ::ModCombatMovement.SkillsInUse == 0 && this.m.CurrentMovementType == ::Const.Tactical.MovementType.Default)
			{
				local id = this.getID();
				local hexes = id in ::ModCombatMovement.PendingHexes ? ::ModCombatMovement.PendingHexes[id] : 0;
				::ModCombatMovement.PendingHexes[id] <- hexes + 1;
			}

			return ret;
		}

		q.onMovementUndo = @(__original) function( _tile, _levelDifference )
		{
			local id = this.getID();

			if (id in ::ModCombatMovement.PendingHexes && ::ModCombatMovement.PendingHexes[id] > 0)
			{
				::ModCombatMovement.PendingHexes[id] = ::ModCombatMovement.PendingHexes[id] - 1;
			}

			return __original(_tile, _levelDifference);
		}

		q.onMovementFinish = @(__original) function( _tile )
		{
			local id = this.getID();

			if (id in ::ModCombatMovement.PendingHexes)
			{
				local hexes = ::ModCombatMovement.PendingHexes[id];
				delete ::ModCombatMovement.PendingHexes[id];

				// Added before the original, which ends with Skills.update()
				if (hexes > 0 && this.isAlive())
				{
					local effect = this.getSkills().getSkillByID(::ModCombatMovement.EffectID);

					if (effect == null)
					{
						effect = ::new(::ModCombatMovement.EffectScript);
						this.getSkills().add(effect);
					}
					else if (effect.isGarbage())
					{
						// Removed earlier this frame and not collected yet
						effect.revive();
					}

					effect.addHexes(hexes);
				}
			}

			return __original(_tile);
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
			}

			return ret;
		}
	});
});
