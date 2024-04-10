/datum/xeno_caste/oppressor
	caste_name = "Oppressor"
	display_name = "Oppressor"
	upgrade_name = ""
	caste_desc = "Psychic guardians of the hive. Disrupt and displace tallhosts with mental attacks while shielding sisters from harm"
	caste_type_path = /mob/living/carbon/xenomorph/oppresor

	tier = XENO_TIER_TWO
	upgrade = XENO_UPGRADE_BASETYPE
	wound_type = "oppressor"
	melee_damage = 20
	speed = -0.5
	plasma_max = 800
	plasma_gain = 60
	max_health = 375
	upgrade_threshold = TIER_TWO_THRESHOLD


	deevolves_to = list(/mob/living/carbon/xenomorph/defender)
	can_flags = CASTE_CAN_BE_QUEEN_HEALED|CASTE_CAN_BE_GIVEN_PLASMA|CASTE_CAN_BE_LEADER
	caste_traits = null
	//todo
	soft_armor = list(MELEE = 40, BULLET = 40, LASER = 40, ENERGY = 40, BOMB = 10, BIO = 35, FIRE = 35, ACID = 35)
	shield_strength = 650
	crush_strength = 50
	blast_strength = 45
	minimap_icon = "warlock"
	actions = list(
		/datum/action/ability/xeno_action/xeno_resting,
		/datum/action/ability/xeno_action/watch_xeno,
		/datum/action/ability/activable/xeno/psydrain,
		/datum/action/ability/xeno_action/psychic_whisper,
	)

/datum/xeno_caste/warlock/normal
	upgrade = XENO_UPGRADE_NORMAL

/datum/xeno_caste/oppressor/primordial
	upgrade_name = "Primordial"
	caste_desc = "A hulking beast which instills an annatural fear. Light bends around it's pulsating cortex"
	primordial_message = "Our mind swells by the grace of the queen mother. We will snuff out those of lesser conciousnesses."
	upgrade = XENO_UPGRADE_PRIMO



