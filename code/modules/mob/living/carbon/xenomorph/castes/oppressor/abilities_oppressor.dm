/particles/warlock_charge
	icon = 'icons/effects/particles/generic_particles.dmi'
	icon_state = "lemon"
	width = 100
	height = 100
	count = 300
	spawning = 15
	lifespan = 8
	fade = 12
	grow = -0.02
	velocity = list(0, 3)
	position = generator(GEN_CIRCLE, 15, 17, NORMAL_RAND)
	drift = generator(GEN_VECTOR, list(0, -0.5), list(0, 0.2))
	gravity = list(0, 3)
	scale = generator(GEN_VECTOR, list(0.1, 0.1), list(0.5, 0.5), NORMAL_RAND)
	color = "#6a59b3"

/particles/crush_warning
	icon = 'icons/effects/particles/generic_particles.dmi'
	icon_state = "lemon"
	width = 36
	height = 45
	count = 50
	spawning = 5
	lifespan = 8
	fade = 10
	grow = -0.04
	velocity = list(0, 0.2)
	position = generator(GEN_SPHERE, 15, 17, NORMAL_RAND)
	drift = generator(GEN_VECTOR, list(-0.5, -0.5), list(0.5, 0.5))
	gravity = list(0, 0.6)
	scale = generator(GEN_VECTOR, list(0.3, 0.3), list(0.7, 0.7), NORMAL_RAND)
	color = "#4b3f7e"

// ***************************************
// *********** Paroxysm
// ***************************************

/datum/action/ability/activable/xeno/paroxysm
	name = "paroxysm"
	action_icon_state = "paroxysm"
	desc = " Project a wave which confuses marines and disrupts their aim. Channeling the ability increases the size of the wave, but reduces the duration of the effects."
	ability_cost = 200
	cooldown_duration = 12 SECONDS
	keybind_flags = ABILITY_KEYBIND_USE_ABILITY
	target_flags = ABILITY_TURF_TARGET
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_PSYCHIC_CRUSH,
	)
	///The number of times we can expand our effect radius. Effectively a max radius
	var/max_iterations = 4
	///How many times we have expanded our effect radius
	var/current_iterations = 0
	///timer hash for the timer we use when charging up
	var/channel_loop_timer
	///List of turfs in the effect radius
	var/list/target_turfs
	///list of effects used to visualise area of effect
	var/list/effect_list
	/// A list of all things that had a fliter applied
	var/list/filters_applied
	///max range at which we can cast out ability
	var/ability_range = 7
	///Holder for the orb visual effect
	var/obj/effect/xeno/flux_orb/orb
	/// Used for particles. Holds the particles instead of the mob. See particle_holder for documentation.
	var/obj/effect/abstract/particle_holder/particle_holder
	///The particle type this ability uses
	var/channel_particle = /particles/warlock_charge

/datum/action/ability/activable/xeno/paroxysm/use_ability(atom/target)
	if(channel_loop_timer)
		if(length(target_turfs)) //it shouldn't be possible to do this without any turfs, but just in case
			flux(target_turfs[1])
		return

	var/mob/living/carbon/xenomorph/xeno_owner = owner
	if(xeno_owner.selected_ability != src)
		action_activate()
		return
	if(owner.do_actions || !target || !can_use_action(TRUE) || !check_distance(target, TRUE))
		return fail_activate()

	ADD_TRAIT(xeno_owner, TRAIT_IMMOBILE, PSYCHIC_CRUSH_ABILITY_TRAIT)
	if(!do_after(owner, 0.8 SECONDS, NONE, owner, BUSY_ICON_DANGER, extra_checks = CALLBACK(src, PROC_REF(can_use_action), FALSE, ABILITY_USE_BUSY)))
		REMOVE_TRAIT(xeno_owner, TRAIT_IMMOBILE, PSYCHIC_CRUSH_ABILITY_TRAIT)
		return fail_activate()

	owner.visible_message(span_xenowarning("\The [owner] starts channeling their psychic might!"), span_xenowarning("We start channeling our psychic might!"))
	REMOVE_TRAIT(xeno_owner, TRAIT_IMMOBILE, PSYCHIC_CRUSH_ABILITY_TRAIT)
	owner.add_movespeed_modifier(MOVESPEED_ID_WARLOCK_CHANNELING, TRUE, 0, NONE, TRUE, 0.9)

	particle_holder = new(owner, channel_particle)
	particle_holder.pixel_x = 16
	particle_holder.pixel_y = 5

	xeno_owner.update_glow(3, 3, "#6a59b3")

	var/turf/target_turf = get_turf(target)
	LAZYINITLIST(target_turfs)
	target_turfs += target_turf
	LAZYINITLIST(effect_list)
	effect_list += new /obj/effect/xeno/flux_warning(target_turf)
	orb = new /obj/effect/xeno/flux_orb(target_turf)

	action_icon_state = "paroxysm_activate"
	update_button_icon()
	RegisterSignals(owner, list(SIGNAL_ADDTRAIT(TRAIT_FLOORED), SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED)), PROC_REF(stop_flux))
	do_channel(target_turf)

///Checks if the owner is close enough/can see the target
/datum/action/ability/activable/xeno/paroxysm/proc/check_distance(atom/target, sight_needed)
	if(get_dist(owner, target) > ability_range)
		owner.balloon_alert(owner, "Too far!")
		return FALSE
	if(sight_needed && !line_of_sight(owner, target, 9))
		owner.balloon_alert(owner, "Out of sight!")
		return FALSE
	return TRUE

///Increases the area of effect, or triggers the flux if we've reached max iterations
/datum/action/ability/activable/xeno/paroxysm/proc/do_channel(turf/target)
	channel_loop_timer = null
	var/mob/living/carbon/xenomorph/xeno_owner = owner
	if(!check_distance(target) || isnull(xeno_owner) || xeno_owner.stat == DEAD)
		stop_flux()
		return
	if(current_iterations >= max_iterations)
		flux(target)
		return

	playsound(target, 'sound/effects/woosh_swoosh.ogg', 30 + (current_iterations * 10))

	var/list/turfs_to_add = list()
	for(var/turf/current_turf AS in target_turfs)
		var/list/turfs_to_check = get_adjacent_open_turfs(current_turf)
		for(var/turf/turf_to_check AS in turfs_to_check)
			if((turf_to_check in target_turfs) || (turf_to_check in turfs_to_add))
				continue
			if(LinkBlocked(current_turf, turf_to_check, air_pass = TRUE))
				continue
			turfs_to_add += turf_to_check
			effect_list += new /obj/effect/xeno/flux_warning(turf_to_check)
	target_turfs += turfs_to_add
	current_iterations ++
	if(can_use_action(xeno_owner, ABILITY_IGNORE_COOLDOWN))
		channel_loop_timer = addtimer(CALLBACK(src, PROC_REF(do_channel), target), 0.6 SECONDS, TIMER_STOPPABLE)
		return

	stop_flux()

///Flux on all turfs in the AOE
/datum/action/ability/activable/xeno/paroxysm/proc/flux(turf/target)
	var/mob/living/carbon/xenomorph/xeno_owner = owner
	//Calculate the confusion effect durations by subtracting from max duration based on current_iterations
	var/confuse_dur = xeno_owner.xeno_caste.flux_max_confuse_dur SECONDS - current_iterations * 0.8 SECONDS
	if(!check_distance(target))
		stop_flux()
		return

	succeed_activate(ability_cost)
	playsound(target, 'sound/effects/EMPulse.ogg', 70)
	apply_filters(target_turfs)
	orb.icon_state = "paroxysm_hard" //used as a check in stop_crush
	flick("paroxysm_hard",orb)
	addtimer(CALLBACK(src, PROC_REF(remove_all_filters)), 1 SECONDS, TIMER_STOPPABLE)

	for(var/turf/effected_turf AS in target_turfs)
		for(var/victim in effected_turf)
			if(iscarbon(victim))
				var/mob/living/carbon/carbon_victim = victim
				if(isxeno(carbon_victim) || carbon_victim.stat == DEAD)
					continue
				//apply bonus brain damage. does not affect sleeping/unconcious marines to prevent (simple forms of) abuse
				if(HAS_TRAIT(carbon_victim, TRAIT_STAGGERED) & carbon_victim.stat == CONSCIOUS)
					carbon_victim.adjustBrainLoss(xeno_owner.xeno_caste.flux_bonus_brain_damage)
					carbon_victim.emote("pain")
					carbon_victim.balloon_alert("Your brain is searing!")
				//apply gun skill debuff and confusion based on confuse_dur
				carbon_victim.apply_status_effect(STATUS_EFFECT_GUN_SKILL_SCATTER_DEBUFF, confuse_dur)
				carbon_victim.apply_status_effect(STATUS_EFFECT_CONFUSED, confuse_dur)
				//apply flat stagger and slowdown
				carbon_victim.adjust_stagger(xeno_owner.xeno_caste.flux_stagger_dur)
				carbon_victim.add_slowdown(xeno_owner.xeno_caste.flux_slowdown_dur)

	stop_flux()

/// stops channeling and unregisters all listeners, resetting the ability
/datum/action/ability/activable/xeno/paroxysm/proc/stop_flux()
	SIGNAL_HANDLER
	var/mob/living/carbon/xenomorph/xeno_owner = owner
	if(channel_loop_timer)
		deltimer(channel_loop_timer)
		channel_loop_timer = null
	QDEL_LIST(effect_list)
	if(orb.icon_state != "flux_orb_hard") //we failed to cast
		flick("flux_orb_smooth", orb)
		QDEL_NULL_IN(src, orb, 0.5 SECONDS)
	else
		QDEL_NULL_IN(src, orb, 0.4 SECONDS)
	current_iterations = 0
	target_turfs = null
	effect_list = null
	owner.remove_movespeed_modifier(MOVESPEED_ID_WARLOCK_CHANNELING)
	action_icon_state = "paroxysm"
	xeno_owner.update_glow()
	add_cooldown()
	update_button_icon()
	QDEL_NULL(particle_holder)
	UnregisterSignal(owner, list(SIGNAL_ADDTRAIT(TRAIT_FLOORED), SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED)))

///Apply a filter on all items in the list of turfs
/datum/action/ability/activable/xeno/paroxysm/proc/apply_filters(list/turfs)
	LAZYINITLIST(filters_applied)
	for(var/turf/targeted AS in turfs)
		targeted.add_filter("crushblur", 1, radial_blur_filter(0.3))
		filters_applied += targeted
		for(var/atom/movable/item AS in targeted.contents)
			item.add_filter("crushblur", 1, radial_blur_filter(0.3))
			filters_applied += item


///Remove all filters of items in filters_applied
/datum/action/ability/activable/xeno/paroxysm/proc/remove_all_filters()
	for(var/atom/thing AS in filters_applied)
		if(QDELETED(thing))
			continue
		thing.remove_filter("crushblur")
	filters_applied = null

/datum/action/ability/activable/xeno/paroxysm/on_cooldown_finish()
	owner.balloon_alert(owner, "Flux ready")
	return ..()

/obj/effect/xeno/flux_warning
	icon = 'icons/xeno/Effects.dmi'
	icon_state = "generic_warning"
	anchored = TRUE
	resistance_flags = RESIST_ALL
	layer = ABOVE_ALL_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	color = COLOR_DARK_RED
	/// Used for particles. Holds the particles instead of the mob. See particle_holder for documentation.
	var/obj/effect/abstract/particle_holder/particle_holder
	///The particle type this ability uses
	var/channel_particle = /particles/flux_warning

/obj/effect/xeno/flux_warning/Initialize(mapload)
	. = ..()
	particle_holder = new(src, channel_particle)
	particle_holder.pixel_y = 0

/obj/effect/xeno/flux_orb
	icon = 'icons/xeno/2x2building.dmi'
	icon_state = "flux_orb_idle"
	anchored = TRUE
	resistance_flags = RESIST_ALL
	layer = FLY_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	alpha = 200
	pixel_x = -16
	pixel_y = 24

/obj/effect/xeno/flux_orb/Initialize(mapload)
	. = ..()
	flick("flux_orb_appear", src)

// ***************************************
// *********** Psychic Assault
// ***************************************
/datum/action/ability/activable/xeno/forward_charge
	name = "Forward Charge"
	action_icon_state = "pounce"
	desc = "Charge up to 5 tiles and knockdown any targets in our way. Strikes fear in nearby marines"
	cooldown_duration = 10 SECONDS
	ability_cost = 80
	use_state_flags = ABILITY_USE_CRESTED|ABILITY_USE_FORTIFIED
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_FORWARD_CHARGE,
	)
	///How long is the windup before charging
	var/windup_time = 0.5 SECONDS

/datum/action/ability/activable/xeno/forward_charge/proc/charge_complete()
	SIGNAL_HANDLER
	UnregisterSignal(owner, list(COMSIG_XENO_OBJ_THROW_HIT, COMSIG_XENO_LIVING_THROW_HIT, COMSIG_MOVABLE_POST_THROW))

/datum/action/ability/activable/xeno/forward_charge/proc/mob_hit(datum/source, mob/M)
	SIGNAL_HANDLER
	if(M.stat || isxeno(M))
		return
	return COMPONENT_KEEP_THROWING

/datum/action/ability/activable/xeno/forward_charge/proc/obj_hit(datum/source, obj/target, speed)
	SIGNAL_HANDLER
	if(istype(target, /obj/structure/table))
		var/obj/structure/S = target
		owner.visible_message(span_danger("[owner] plows straight through [S]!"), null, null, 5)
		S.deconstruct(FALSE) //We want to continue moving, so we do not reset throwing.
		return // stay registered
	target.hitby(owner, speed) //This resets throwing.
	charge_complete()

/datum/action/ability/activable/xeno/forward_charge/can_use_ability(atom/A, silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE
	if(!A)
		return FALSE

/datum/action/ability/activable/xeno/forward_charge/on_cooldown_finish()
	to_chat(owner, span_xenodanger("Our exoskeleton quivers as we get ready to use Forward Charge again."))
	playsound(owner, "sound/effects/xeno_newlarva.ogg", 50, 0, 1)
	return ..()

/datum/action/ability/activable/xeno/forward_charge/use_ability(atom/A)
	var/mob/living/carbon/xenomorph/X = owner

	if(!do_after(X, windup_time, IGNORE_HELD_ITEM, X, BUSY_ICON_DANGER, extra_checks = CALLBACK(src, PROC_REF(can_use_ability), A, FALSE, ABILITY_USE_BUSY)))
		return fail_activate()

	var/mob/living/carbon/xenomorph/defender/defender = X
	if(defender.fortify)
		var/datum/action/ability/xeno_action/fortify/fortify_action = X.actions_by_path[/datum/action/ability/xeno_action/fortify]

		fortify_action.set_fortify(FALSE, TRUE)
		fortify_action.add_cooldown()
		to_chat(X, span_xenowarning("We rapidly untuck ourselves, preparing to surge forward."))

	X.visible_message(span_danger("[X] charges towards \the [A]!"), \
	span_danger("We charge towards \the [A]!") )
	X.emote("roar")
	succeed_activate()

	RegisterSignal(X, COMSIG_XENO_OBJ_THROW_HIT, PROC_REF(obj_hit))
	RegisterSignal(X, COMSIG_XENO_LIVING_THROW_HIT, PROC_REF(mob_hit))
	RegisterSignal(X, COMSIG_MOVABLE_POST_THROW, PROC_REF(charge_complete))

	X.throw_at(A, DEFENDER_CHARGE_RANGE, 5, X)

	add_cooldown()

/datum/action/ability/activable/xeno/forward_charge/ai_should_start_consider()
	return TRUE

/datum/action/ability/activable/xeno/forward_charge/ai_should_use(atom/target)
	if(!iscarbon(target))
		return FALSE
	if(!line_of_sight(owner, target, DEFENDER_CHARGE_RANGE))
		return FALSE
	if(!can_use_action(override_flags = ABILITY_IGNORE_SELECTED_ABILITY))
		return FALSE
	if(target.get_xeno_hivenumber() == owner.get_xeno_hivenumber())
		return FALSE
	action_activate()
	LAZYINCREMENT(owner.do_actions, target)
	addtimer(CALLBACK(src, PROC_REF(decrease_do_action), target), windup_time)
	return TRUE

///Decrease the do_actions of the owner
/datum/action/ability/activable/xeno/forward_charge/proc/decrease_do_action(atom/target)
	LAZYDECREMENT(owner.do_actions, target)

// ***************************************
// *********** Fortify
// ***************************************
/datum/action/ability/xeno_action/fortify
	name = "Fortify"
	action_icon_state = "fortify"	// TODO
	desc = "Plant yourself for a large defensive boost."
	use_state_flags = ABILITY_USE_FORTIFIED|ABILITY_USE_CRESTED // duh
	cooldown_duration = 1 SECONDS
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_FORTIFY,
	)
	var/last_fortify_bonus = 0

/datum/action/ability/xeno_action/fortify/give_action()
	. = ..()
	var/mob/living/carbon/xenomorph/defender/X = owner
	last_fortify_bonus = X.xeno_caste.fortify_armor

/datum/action/ability/xeno_action/fortify/on_xeno_upgrade()
	var/mob/living/carbon/xenomorph/X = owner
	if(X.fortify)
		X.soft_armor = X.soft_armor.modifyAllRatings(-last_fortify_bonus)
		X.soft_armor = X.soft_armor.modifyRating(BOMB = -last_fortify_bonus)

		last_fortify_bonus = X.xeno_caste.fortify_armor

		X.soft_armor = X.soft_armor.modifyAllRatings(last_fortify_bonus)
		X.soft_armor = X.soft_armor.modifyRating(BOMB = last_fortify_bonus)
	else
		last_fortify_bonus = X.xeno_caste.fortify_armor

/datum/action/ability/xeno_action/fortify/on_cooldown_finish()
	var/mob/living/carbon/xenomorph/X = owner
	to_chat(X, span_notice("We can [X.fortify ? "stand up" : "fortify"] again."))
	return ..()

/datum/action/ability/xeno_action/fortify/action_activate()
	var/mob/living/carbon/xenomorph/defender/X = owner

	if(X.fortify)
		set_fortify(FALSE)
		add_cooldown()
		return succeed_activate()

	var/was_crested = X.crest_defense
	if(X.crest_defense)
		var/datum/action/ability/xeno_action/toggle_crest_defense/CD = X.actions_by_path[/datum/action/ability/xeno_action/toggle_crest_defense]
		if(CD.cooldown_timer)
			to_chat(X, span_xenowarning("We cannot yet transition to a defensive stance!"))
			return fail_activate()
		CD.set_crest_defense(FALSE, TRUE)
		CD.add_cooldown()
		to_chat(X, span_xenowarning("We tuck our lowered crest into ourselves."))

	var/datum/action/ability/activable/xeno/charge/forward_charge/combo_cooldown = X.actions_by_path[/datum/action/ability/activable/xeno/charge/forward_charge]
	combo_cooldown.add_cooldown(cooldown_duration)

	set_fortify(TRUE, was_crested)
	add_cooldown()
	return succeed_activate()

/datum/action/ability/xeno_action/fortify/proc/set_fortify(on, silent = FALSE)
	var/mob/living/carbon/xenomorph/defender/X = owner
	GLOB.round_statistics.defender_fortifiy_toggles++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "defender_fortifiy_toggles")
	if(on)
		ADD_TRAIT(X, TRAIT_IMMOBILE, FORTIFY_TRAIT)
		ADD_TRAIT(X, TRAIT_STOPS_TANK_COLLISION, FORTIFY_TRAIT)
		if(!silent)
			to_chat(X, span_xenowarning("We tuck ourselves into a defensive stance."))
		X.soft_armor = X.soft_armor.modifyAllRatings(last_fortify_bonus)
		X.soft_armor = X.soft_armor.modifyRating(BOMB = last_fortify_bonus) //double bomb bonus for explosion immunity
	else
		if(!silent)
			to_chat(X, span_xenowarning("We resume our normal stance."))
		X.soft_armor = X.soft_armor.modifyAllRatings(-last_fortify_bonus)
		X.soft_armor = X.soft_armor.modifyRating(BOMB = -last_fortify_bonus)
		REMOVE_TRAIT(X, TRAIT_IMMOBILE, FORTIFY_TRAIT)
		REMOVE_TRAIT(X, TRAIT_STOPS_TANK_COLLISION, FORTIFY_TRAIT)

	X.fortify = on
	X.anchored = on
	playsound(X.loc, 'sound/effects/stonedoor_openclose.ogg', 30, TRUE)
	X.update_icons()

// ***************************************
// *********** Psychic Fortress
// ***************************************
