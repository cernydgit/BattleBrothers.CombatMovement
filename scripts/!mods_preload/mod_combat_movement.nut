::ModCombatMovement <- {
	ID = "mod_combat_movement",
	Name = "Combat Movement",
	Version = "1.3.0",
	EffectID = "effects.mod_combat_movement_moving",
	EffectScript = "scripts/skills/effects/mod_combat_movement_effect",
	// Used when MSU is not installed, and as the defaults of the mod settings
	// Damage bonus in % = hexes * BaseBonus + hexes^2 * DynamicBonus
	Defaults = {
		BaseBonus = 5,
		DynamicBonus = 5,
		MaxHexes = 3,
		KnockBackMaxDistance = 2
	},
	// Skills whose AP cost drops by (counted hexes - 1): thrusting attacks
	// (spear, dagger, pike, pitchfork, spetum, qatal) and the shield Knock Back
	MomentumSkillIDs = {
		["actives.thrust"] = true,
		["actives.stab"] = true,
		["actives.puncture"] = true,
		["actives.impale"] = true,
		["actives.prong"] = true,
		["actives.rupture"] = true,
		["actives.deathblow"] = true,
		["actives.knock_back"] = true
	},
	// Same, matched by script name for skills without a known ID (Estoc)
	MomentumClassNames = {
		estoc_stab_skill = true
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

// The Moving effect of the actor, or null when it has none or already spent it on a skill
::ModCombatMovement.getMomentumEffect <- function( _actor )
{
	if (_actor == null)
	{
		return null;
	}

	local effect = _actor.getSkills().getSkillByID(::ModCombatMovement.EffectID);
	return effect != null && effect.hasMomentum() ? effect : null;
};

::ModCombatMovement.isMomentumSkill <- function( _skill )
{
	if (_skill.getID() in ::ModCombatMovement.MomentumSkillIDs)
	{
		return true;
	}

	try
	{
		return _skill.ClassName in ::ModCombatMovement.MomentumClassNames;
	}
	catch( e )
	{
		return false;
	}
};

// The vanilla first tile (with its sideways fallbacks), then further in the
// same direction while the next tile is free and at most 1 level apart
::ModCombatMovement.findKnockBackTile <- function( _skill, _userTile, _targetTile, _distance )
{
	local tile = _skill.findTileToKnockBackTo(_userTile, _targetTile);

	if (tile == null)
	{
		return null;
	}

	local dir = _targetTile.getDirectionTo(tile);

	for( local i = 1; i < _distance; ++i )
	{
		if (!tile.hasNextTile(dir))
		{
			break;
		}

		local next = tile.getNextTile(dir);

		if (!next.IsEmpty || ::Math.abs(next.Level - tile.Level) > 1)
		{
			break;
		}

		tile = next;
	}

	return tile;
};

::ModCombatMovement.onKnockedDown <- function( _entity, _tag )
{
	if (_entity.isAlive() && _tag.HitInfo.DamageRegular != 0)
	{
		_entity.onDamageReceived(_tag.Attacker, _tag.Skill, _tag.HitInfo);
	}
};

// Knock Back used with momentum: same flow as vanilla, plus stagger (1+ hexes),
// stun (2+ hexes) on a hit, and a push of up to the counted hexes
::ModCombatMovement.useKnockBack <- function( _skill, _effect, _user, _targetTile )
{
	local target = _targetTile.getEntity();
	local hexes = _effect.getCountedHexes();
	local isVisible = !_user.isHiddenToPlayer() && _targetTile.IsVisibleForPlayer;
	local hitChance = _skill.getHitchance(target);
	local roll = ::Math.rand(1, 100);

	if (roll > hitChance)
	{
		if (isVisible)
		{
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " uses " + _skill.getName() + " and misses " + ::Const.UI.getColorizedEntityName(target) + " (Chance: " + hitChance + ", Rolled: " + roll + ")");
		}

		target.onMissed(_user, _skill);
		::ModCombatMovement.log(_user.getName() + " missed Knock Back on " + target.getName());
		return false;
	}

	if (isVisible)
	{
		::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " uses " + _skill.getName() + " and hits " + ::Const.UI.getColorizedEntityName(target) + " (Chance: " + hitChance + ", Rolled: " + roll + ")");
	}

	_skill.applyFatigueDamage(target, 10);

	target.getSkills().add(::new("scripts/skills/effects/staggered_effect"));

	if (isVisible)
	{
		::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " has staggered " + ::Const.UI.getColorizedEntityName(target) + " for one turn");
	}

	if (hexes >= 2 && !target.getCurrentProperties().IsImmuneToStun)
	{
		target.getSkills().add(::new("scripts/skills/effects/stunned_effect"));

		if (isVisible)
		{
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " has stunned " + ::Const.UI.getColorizedEntityName(target) + " for one turn");
		}
	}

	local knockToTile = ::ModCombatMovement.findKnockBackTile(_skill, _user.getTile(), _targetTile, _effect.getKnockBackDistance());

	if (knockToTile == null || target.getCurrentProperties().IsImmuneToKnockBackAndGrab)
	{
		::ModCombatMovement.log(_user.getName() + " hit " + target.getName() + " with Knock Back (" + hexes + " hexes), no push");
		return true;
	}

	local distance = _targetTile.getDistanceTo(knockToTile);

	if (!_user.isHiddenToPlayer() && (_targetTile.IsVisibleForPlayer || knockToTile.IsVisibleForPlayer))
	{
		::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " has knocked back " + ::Const.UI.getColorizedEntityName(target) + " by " + distance + " tile" + (distance == 1 ? "" : "s"));
	}

	local skills = target.getSkills();
	skills.removeByID("effects.shieldwall");
	skills.removeByID("effects.spearwall");
	skills.removeByID("effects.riposte");

	if (_skill.m.SoundOnHit.len() != 0)
	{
		::Sound.play(_skill.m.SoundOnHit[::Math.rand(0, _skill.m.SoundOnHit.len() - 1)], ::Const.Sound.Volume.Skill, _user.getPos());
	}

	target.setCurrentMovementType(::Const.Tactical.MovementType.Involuntary);
	local damage = ::Math.max(0, ::Math.abs(knockToTile.Level - _targetTile.Level) - 1) * ::Const.Combat.FallingDamage;

	if (damage == 0)
	{
		::Tactical.getNavigator().teleport(target, knockToTile, null, null, true);
	}
	else
	{
		local tag = {
			Attacker = _user,
			Skill = _skill,
			HitInfo = clone ::Const.Tactical.HitInfo
		};
		tag.HitInfo.DamageRegular = damage;
		tag.HitInfo.DamageDirect = 1.0;
		tag.HitInfo.BodyPart = ::Const.BodyPart.Body;
		tag.HitInfo.BodyDamageMult = 1.0;
		tag.HitInfo.FatalityChanceMult = 1.0;
		::Tactical.getNavigator().teleport(target, knockToTile, ::ModCombatMovement.onKnockedDown, tag, true);
	}

	::ModCombatMovement.log(_user.getName() + " hit " + target.getName() + " with Knock Back (" + hexes + " hexes), pushed " + distance + " tile(s)");
	return true;
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
		page.addRangeSetting("KnockBackMaxDistance", ::ModCombatMovement.Defaults.KnockBackMaxDistance, 1, 5, 1, "Knock Back max distance", "Maximum number of tiles Knock Back pushes the target after the character walked.");
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

		// Thrusting attacks and Knock Back cost less with momentum. The cost is
		// paid in use() before the effect is spent, so the attack itself is cheaper.
		q.getActionPointCost = @(__original) function()
		{
			local cost = __original();

			if (cost <= 1 || this.m.Container == null || !::ModCombatMovement.isMomentumSkill(this))
			{
				return cost;
			}

			local effect = ::ModCombatMovement.getMomentumEffect(this.m.Container.getActor());

			if (effect == null)
			{
				return cost;
			}

			return ::Math.max(1, cost - effect.getActionPointReduction());
		}
	});

	::ModCombatMovement.Mod.hook("scripts/skills/actives/knock_back", function( q )
	{
		q.onUse = @(__original) function( _user, _targetTile )
		{
			local effect = ::ModCombatMovement.getMomentumEffect(_user);

			if (effect == null || !_targetTile.IsOccupiedByActor)
			{
				return __original(_user, _targetTile);
			}

			return ::ModCombatMovement.useKnockBack(this, effect, _user, _targetTile);
		}
	});
});
