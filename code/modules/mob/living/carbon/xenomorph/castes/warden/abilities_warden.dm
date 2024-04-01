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
	name = "Psychic Crush"
	action_icon_state = "psy_crush"
	desc = "Channel an expanding AOE crush effect, activating it again pre-maturely crushes enemies over an area. The longer it is channeled, the larger area it will affect, but will consume more plasma."
	ability_cost = 40
	cooldown_duration = 12 SECONDS
	keybind_flags = ABILITY_KEYBIND_USE_ABILITY
	target_flags = ABILITY_TURF_TARGET
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_PSYCHIC_CRUSH,
	)
	///The number of times we can expand our effect radius. Effectively a max radius
	var/max_interations = 5
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
	var/obj/effect/xeno/crush_orb/orb
	/// Used for particles. Holds the particles instead of the mob. See particle_holder for documentation.
	var/obj/effect/abstract/particle_holder/particle_holder
	///The particle type this ability uses
	var/channel_particle = /particles/warlock_charge

/datum/action/ability/activable/xeno/psy_crush/use_ability(atom/target)
	if(channel_loop_timer)
		if(length(target_turfs)) //it shouldn't be possible to do this without any turfs, but just in case
			crush(target_turfs[1])
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
	effect_list += new /obj/effect/xeno/crush_warning(target_turf)
	orb = new /obj/effect/xeno/crush_orb(target_turf)

	action_icon_state = "psy_crush_activate"
	update_button_icon()
	RegisterSignals(owner, list(SIGNAL_ADDTRAIT(TRAIT_FLOORED), SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED)), PROC_REF(stop_crush))
	do_channel(target_turf)

///Checks if the owner is close enough/can see the target
/datum/action/ability/activable/xeno/psy_crush/proc/check_distance(atom/target, sight_needed)
	if(get_dist(owner, target) > ability_range)
		owner.balloon_alert(owner, "Too far!")
		return FALSE
	if(sight_needed && !line_of_sight(owner, target, 9))
		owner.balloon_alert(owner, "Out of sight!")
		return FALSE
	return TRUE

///Increases the area of effect, or triggers the crush if we've reached max iterations
/datum/action/ability/activable/xeno/psy_crush/proc/do_channel(turf/target)
	channel_loop_timer = null
	var/mob/living/carbon/xenomorph/xeno_owner = owner
	if(!check_distance(target) || isnull(xeno_owner) || xeno_owner.stat == DEAD)
		stop_crush()
		return
	if(current_iterations >= max_interations)
		crush(target)
		return

	succeed_activate()
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
			effect_list += new /obj/effect/xeno/crush_warning(turf_to_check)
	target_turfs += turfs_to_add
	current_iterations ++
	if(can_use_action(xeno_owner, ABILITY_IGNORE_COOLDOWN))
		channel_loop_timer = addtimer(CALLBACK(src, PROC_REF(do_channel), target), 0.6 SECONDS, TIMER_STOPPABLE)
		return

	stop_crush()

///crushes all turfs in the AOE
/datum/action/ability/activable/xeno/psy_crush/proc/crush(turf/target)
	var/mob/living/carbon/xenomorph/xeno_owner = owner
	var/crush_cost = ability_cost * current_iterations
	if(crush_cost > xeno_owner.plasma_stored)
		owner.balloon_alert(owner, "[crush_cost - xeno_owner.plasma_stored] more plasma!")
		stop_crush()
		return
	if(!check_distance(target))
		stop_crush()
		return

	succeed_activate(crush_cost)
	playsound(target, 'sound/effects/EMPulse.ogg', 70)
	apply_filters(target_turfs)
	orb.icon_state = "crush_hard" //used as a check in stop_crush
	flick("crush_hard", orb)
	addtimer(CALLBACK(src, PROC_REF(remove_all_filters)), 1 SECONDS, TIMER_STOPPABLE)

	for(var/turf/effected_turf AS in target_turfs)
		for(var/victim in effected_turf)
			if(iscarbon(victim))
				var/mob/living/carbon/carbon_victim = victim
				if(isxeno(carbon_victim) || carbon_victim.stat == DEAD)
					continue
				carbon_victim.apply_damage(xeno_owner.xeno_caste.crush_strength, BRUTE, blocked = BOMB)
				carbon_victim.apply_damage(xeno_owner.xeno_caste.crush_strength * 1.5, STAMINA, blocked = BOMB)
				carbon_victim.adjust_stagger(5 SECONDS)
				carbon_victim.add_slowdown(6)
			else if(ismecha(victim))
				var/obj/vehicle/sealed/mecha/mecha_victim = victim
				mecha_victim.take_damage(xeno_owner.xeno_caste.crush_strength * 5, BRUTE, BOMB)
	stop_crush()

/// stops channeling and unregisters all listeners, resetting the ability
/datum/action/ability/activable/xeno/psy_crush/proc/stop_crush()
	SIGNAL_HANDLER
	var/mob/living/carbon/xenomorph/xeno_owner = owner
	if(channel_loop_timer)
		deltimer(channel_loop_timer)
		channel_loop_timer = null
	QDEL_LIST(effect_list)
	if(orb.icon_state != "crush_hard") //we failed to crush
		flick("crush_smooth", orb)
		QDEL_NULL_IN(src, orb, 0.5 SECONDS)
	else
		QDEL_NULL_IN(src, orb, 0.4 SECONDS)
	current_iterations = 0
	target_turfs = null
	effect_list = null
	owner.remove_movespeed_modifier(MOVESPEED_ID_WARLOCK_CHANNELING)
	action_icon_state = "psy_crush"
	xeno_owner.update_glow()
	add_cooldown()
	update_button_icon()
	QDEL_NULL(particle_holder)
	UnregisterSignal(owner, list(SIGNAL_ADDTRAIT(TRAIT_FLOORED), SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED)))

///Apply a filter on all items in the list of turfs
/datum/action/ability/activable/xeno/psy_crush/proc/apply_filters(list/turfs)
	LAZYINITLIST(filters_applied)
	for(var/turf/targeted AS in turfs)
		targeted.add_filter("crushblur", 1, radial_blur_filter(0.3))
		filters_applied += targeted
		for(var/atom/movable/item AS in targeted.contents)
			item.add_filter("crushblur", 1, radial_blur_filter(0.3))
			filters_applied += item
	GLOB.round_statistics.psy_crushes++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "psy_crushes")

///Remove all filters of items in filters_applied
/datum/action/ability/activable/xeno/psy_crush/proc/remove_all_filters()
	for(var/atom/thing AS in filters_applied)
		if(QDELETED(thing))
			continue
		thing.remove_filter("crushblur")
	filters_applied = null

/datum/action/ability/activable/xeno/psy_crush/on_cooldown_finish()
	owner.balloon_alert(owner, "Crush ready")
	return ..()

/obj/effect/xeno/crush_warning
	icon = 'icons/xeno/Effects.dmi'
	icon_state = "crush_warning"
	anchored = TRUE
	resistance_flags = RESIST_ALL
	layer = ABOVE_ALL_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// Used for particles. Holds the particles instead of the mob. See particle_holder for documentation.
	var/obj/effect/abstract/particle_holder/particle_holder
	///The particle type this ability uses
	var/channel_particle = /particles/crush_warning

/obj/effect/xeno/crush_warning/Initialize(mapload)
	. = ..()
	particle_holder = new(src, channel_particle)
	particle_holder.pixel_y = 0

/obj/effect/xeno/crush_orb
	icon = 'icons/xeno/2x2building.dmi'
	icon_state = "orb_idle"
	anchored = TRUE
	resistance_flags = RESIST_ALL
	layer = FLY_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	pixel_x = -16

/obj/effect/xeno/crush_orb/Initialize(mapload)
	. = ..()
	flick("orb_charge", src)


// ***************************************
// *********** Forward Charge
// ***************************************
/datum/action/ability/activable/xeno/forward_charge
	name = "Forward Charge"
	action_icon_state = "pounce"
	desc = "Charge up to 4 tiles and knockdown any targets in our way."
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
