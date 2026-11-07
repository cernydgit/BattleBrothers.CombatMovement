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
		this.m.Icon = "skills/mod_combat_movement_moving.png";
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
		return this.getCountedHexes() * ::ModCombatMovement.getSetting("DamagePerHex");
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
		return "This character is on the move and carries its momentum into the next blow. Every hex walked adds to the damage dealt, up to [color=" + this.Const.UI.Color.PositiveValue + "]" + this.getMaxHexes() + "[/color] hexes. The momentum lasts into the next round, but is lost when the character waits or uses any skill.";
	}

	function getTooltip()
	{
		return [
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
