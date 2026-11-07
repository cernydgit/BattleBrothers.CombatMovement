this.mod_combat_movement_effect <- this.inherit("scripts/skills/skill", {
	m = {
		// Hexes walked since the effect was gained (capped when the bonus is computed)
		Hexes = 0,
		// Set when the character used a skill. The effect is then hidden and only
		// boosts that skill until it is resolved; it is removed on the next skill
		// use or at turn end, and walking again starts it over.
		IsConsumed = false,
		ConsumedBySkillID = ""
	},
	function create()
	{
		this.m.ID = ::ModCombatMovement.EffectID;
		this.m.Name = "Moving";
		// Vanilla Pathfinder perk icon (there is no perk_23_mini brush for the battlefield)
		this.m.Icon = "ui/perks/perk_23.png";
		this.m.IconMini = "";
		this.m.Overlay = "";
		this.m.Type = this.Const.SkillType.StatusEffect;
		this.m.Order = this.Const.SkillOrder.VeryLast;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsSerialized = false;
		this.m.IsRemovedAfterBattle = true;
	}

	function getMaxHexes()
	{
		return ::ModCombatMovement.getSetting("MaxHexes");
	}

	function getCountedHexes()
	{
		return this.Math.min(this.m.Hexes, this.getMaxHexes());
	}

	function getBonusPercent()
	{
		local hexes = this.getCountedHexes();
		return hexes * ::ModCombatMovement.getSetting("BaseBonus") + hexes * hexes * ::ModCombatMovement.getSetting("DynamicBonus");
	}

	// True while the momentum can still be used (not spent on a skill yet)
	function hasMomentum()
	{
		return !this.m.IsConsumed && !this.isGarbage();
	}

	// Thrusting attacks and Knock Back cost (counted hexes - 1) AP less
	function getActionPointReduction()
	{
		return this.hasMomentum() ? this.Math.max(0, this.getCountedHexes() - 1) : 0;
	}

	// Knock Back pushes the target 1 + (counted hexes - 1) tiles, up to the max distance setting
	function getKnockBackDistance()
	{
		return this.Math.min(this.Math.max(1, this.getCountedHexes()), ::ModCombatMovement.getSetting("KnockBackMaxDistance"));
	}

	function isHidden()
	{
		return this.m.IsConsumed || this.skill.isHidden();
	}

	function isConsumed()
	{
		return this.m.IsConsumed;
	}

	function getName()
	{
		return this.m.Name + " (" + this.getCountedHexes() + "/" + this.getMaxHexes() + ")";
	}

	function getDescription()
	{
		return "This character is on the move and carries its momentum into the next blow. The more hexes walked, the faster the damage dealt grows, up to [color=" + this.Const.UI.Color.PositiveValue + "]" + this.getMaxHexes() + "[/color] hexes. The momentum lasts into the next round, but is lost when the character waits or uses any skill.";
	}

	function getTooltip()
	{
		local ret = [
			{
				id = 1,
				type = "title",
				text = this.getName()
			},
			{
				id = 2,
				type = "description",
				text = this.getDescription()
			},
			{
				id = 10,
				type = "text",
				icon = "ui/icons/damage_dealt.png",
				text = "[color=" + this.Const.UI.Color.PositiveValue + "]+" + this.getBonusPercent() + "%[/color] Damage"
			},
			{
				id = 11,
				type = "text",
				icon = "ui/icons/special.png",
				text = "Walked [color=" + this.Const.UI.Color.PositiveValue + "]" + this.m.Hexes + "[/color] hex(es), the maximum bonus is reached at " + this.getMaxHexes()
			}
		];

		local apReduction = this.getActionPointReduction();

		if (apReduction > 0)
		{
			ret.push({
				id = 12,
				type = "text",
				icon = "ui/icons/action_points.png",
				text = "Thrusting attacks and Knock Back cost [color=" + this.Const.UI.Color.PositiveValue + "]" + apReduction + "[/color] AP less (at least 1)"
			});
		}

		local distance = this.getKnockBackDistance();
		ret.push({
			id = 13,
			type = "text",
			icon = "ui/icons/special.png",
			text = "Knock Back " + (this.getCountedHexes() >= 2 ? "[color=" + this.Const.UI.Color.PositiveValue + "]staggers and stuns[/color]" : "[color=" + this.Const.UI.Color.PositiveValue + "]staggers[/color]") + " the target on a hit and pushes it up to [color=" + this.Const.UI.Color.PositiveValue + "]" + distance + "[/color] tile" + (distance == 1 ? "" : "s")
		});

		return ret;
	}

	function addHexes( _hexes )
	{
		// The character moved again after using a skill: start over
		if (this.m.IsConsumed)
		{
			this.m.IsConsumed = false;
			this.m.ConsumedBySkillID = "";
			this.m.Hexes = 0;
		}

		// Never more than the largest possible setting, so the number stays readable
		this.m.Hexes = this.Math.min(this.m.Hexes + _hexes, 10);
	}

	function removeHexes( _hexes )
	{
		this.m.Hexes = this.Math.max(0, this.m.Hexes - _hexes);

		if (this.m.Hexes == 0)
		{
			this.removeSelf();
		}
	}

	function revive()
	{
		this.m.IsGarbage = false;
		this.m.IsConsumed = false;
		this.m.ConsumedBySkillID = "";
		this.m.Hexes = 0;
	}

	function consume( _skill )
	{
		this.m.IsConsumed = true;
		this.m.ConsumedBySkillID = _skill.getID();
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (!_skill.isAttack())
		{
			return;
		}

		if (this.m.IsConsumed && _skill.getID() != this.m.ConsumedBySkillID)
		{
			return;
		}

		_properties.DamageTotalMult *= 1.0 + this.getBonusPercent() / 100.0;
	}

	function onWaitTurn()
	{
		this.removeSelf();
	}

	function onTurnEnd()
	{
		if (this.m.IsConsumed)
		{
			this.removeSelf();
		}
	}

	function onCombatFinished()
	{
		this.removeSelf();
	}

});
