/obj/lombard
	name = "pawnshop"
	desc = "Sell your stuff."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	icon_state = "sell"
	icon = 'code/modules/wod13/props.dmi'
	anchored = TRUE
	var/illegal = FALSE

/obj/lombard/attackby(obj/item/W, mob/living/user, params)
	if(istype(W, /obj/item/stack))
		return
	if(W.illegal == illegal)
		sell_one_item(W, user)
	else
		..()

/obj/lombard/proc/sell_one_item(obj/item/sold, mob/living/user)
	if(!sold.can_sell())
		to_chat(user, sold.on_sale_fail_message())
		return
	sell_item(sold, user)
	playsound(loc, 'code/modules/wod13/sounds/sell.ogg', 50, TRUE)
	to_chat(user, sold.on_sale_success_message())
	var/mob/living/carbon/human/seller = user
	if(istype(seller))
		seller.AdjustHumanity(sold.humanity_loss_on_sale, sold.humanity_loss_on_sale_limit)
	qdel(sold)

//This assumes that all items are of the same type
/obj/lombard/proc/sell_multiple_items(var/list/items_to_sell, mob/living/user)
	var/succeeded_sale
	var/list/sold_items = list() //This will be returned at the end of the proc for use in lombard/MouseDrop_T()
	for(var/obj/item/sold in items_to_sell)
		if(!sold.can_sell())
			to_chat(user, sold.on_sale_fail_message())
			continue
		sell_item(sold, user)
		to_chat(user, sold.on_sale_success_message())
		succeeded_sale = TRUE
		sold_items += sold
	if(succeeded_sale)
		playsound(loc, 'code/modules/wod13/sounds/sell.ogg', 50, TRUE)
	return sold_items
	//Humanity adjustment and item deletion is handled in lombard/MouseDrop_T()

/obj/lombard/proc/sell_item(obj/item/sold, mob/living/user, var/batch_sale = FALSE)
	var/real_value = (sold.cost / 5) * (user.social + (user.additional_social * 0.1))
	var/obj/item/stack/dollar/money_to_spawn = new() //Don't pass off the loc until we add up the money, or else it will merge too early
	//In case we ever add items that sell for more than the maximum amount of dollars in a stack and can be mass-sold, we use this code.
	if(real_value >= money_to_spawn.max_amount)
		money_to_spawn.amount = money_to_spawn.max_amount
		var/extra_money_stack = real_value/money_to_spawn.max_amount - 1 //The -1 is the money already spawned
		if(extra_money_stack > 0)
			for(var/i in 1 to ceil(extra_money_stack)) //0.6 extra_money_stack = a new dollar stack, 1.3 extra_money_stack = two new dollar stacks etc.
				var/obj/item/stack/dollar/extra_money_to_spawn = new()
				if(extra_money_stack >= 1)
					extra_money_to_spawn.amount = extra_money_to_spawn.max_amount
					extra_money_stack -= 1
				else
					extra_money_to_spawn.amount = extra_money_to_spawn.max_amount/extra_money_stack
				extra_money_to_spawn.icon = extra_money_to_spawn.onflooricon
				extra_money_to_spawn.update_icon_state()
				extra_money_to_spawn.forceMove(loc)
	else
		money_to_spawn.amount = real_value
	money_to_spawn.icon = money_to_spawn.onflooricon //The nullspace workaround causes the money to show up in an unintentional way. Manually fix the icon.
	money_to_spawn.update_icon_state()
	money_to_spawn.forceMove(loc)

//Click-dragging to the vendor to mass-sell a certain type of item
/obj/lombard/MouseDrop_T(obj/item/sold, mob/living/user)
	..()
	if(!istype(sold))
		return
	if(sold.illegal != illegal)
		return
	//Briefly copypasting the selling code since for now this is a separate proc compared to selling.
	if(istype(sold, /obj/item/stack))
		return
	if(!user.CanReach(src)) //User has to be near the pawnshop/black market
		return
	if(!user.CanReach(sold)) //User has to be near the goods themselves
		return
	//Supports mass-selling fish, organs, meth and weed.
	var/list/acceptable_types = list(/obj/item/food/fish,
									/obj/item/organ,
									/obj/item/reagent_containers/food/drinks/meth,
									/obj/item/weedpack)
	if(!is_type_in_list(sold, acceptable_types))
		return
	var/turf/turf_with_items = sold.loc
	if(!isturf(turf_with_items)) //No mouse-dragging while it's inside a bag or a container. Has to be on the floor.
		return
	var/mob/living/carbon/human/seller = user
	var/list/item_list_to_sell = list() //Store this list for later, we are currently only doing a count to let the user know of their humanity hit.
	for(var/obj/item/counted_item in turf_with_items)
		if(counted_item.type == sold.type) //Has to be the exact same type
			item_list_to_sell += counted_item
	if(item_list_to_sell.len == 1) //Just one item, sell it normally
		sell_one_item(sold, seller)
		return
	var/humanity_penalty_limit = sold.humanity_loss_on_sale_limit
	if(sold.humanity_loss_on_sale && !seller.clane?.enlightenment) //Do the prompt if the user cares about humanity.
		//We use these variable to determine whether a prospective seller should be notified about their humanity hit, prompting them if they're gonna lose it.
		//Also used to merge the item sales into one AdjustHumanity() proc to avoid excessive noise and chat spam
		var/humanity_loss_modifier = seller.clane ? seller.clane.humanitymod : 1
		var/humanity_loss_risk = item_list_to_sell.len * humanity_loss_modifier * sold.humanity_loss_on_sale
		if(humanity_penalty_limit < seller.humanity) //Check if the user is actually at risk of losing more humanity.
			if(humanity_penalty_limit <= 0 && ((user.humanity + humanity_loss_risk) <= 0)) //User will wight out if they do this, don't offer the alert, just warn the user.
				to_chat(user, "<span class='warning'>Selling all of this will remove all of your Humanity!</span>")
				return
			var/maximum_humanity_loss = min(seller.humanity - humanity_penalty_limit, -humanity_loss_risk)
			var/choice = alert(seller, "Your HUMANITY is currently at [seller.humanity], you will LOSE [maximum_humanity_loss] humanity if you proceed. Do you proceed?",,"Yes", "No")
			if(choice == "No")
				return
			//Check for proximity again
			if(!user.CanReach(src))
				return
			if(!user.CanReach(sold))
				return
	for(var/obj/item/selling_item in item_list_to_sell)
		if(selling_item.loc != turf_with_items) //Item has been moved away.
			item_list_to_sell -= selling_item //Removing items from the list to leave all the items that have been sold. Empty list = no items sold.
			continue
	if(!item_list_to_sell.len)
		return
	var/list/sold_items = sell_multiple_items(item_list_to_sell, seller)
	if(!sold_items.len)
		return
	seller.AdjustHumanity(sold.humanity_loss_on_sale * sold_items.len, humanity_penalty_limit)
	//Leave this deletion at the very end just in case any earlier qdel would decide to hard-del the item and remove the item from the list before actually adjusting humanity and such
	for(var/item_to_delete in sold_items)
		qdel(item_to_delete)

/obj/lombard/blackmarket
	name = "black market"
	desc = "Sell illegal goods."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	icon_state = "sell_d"
	icon = 'code/modules/wod13/props.dmi'
	anchored = TRUE
	illegal = TRUE
