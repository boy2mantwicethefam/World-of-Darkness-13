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
	if(istype(W, /obj/item/organ))
		var/obj/item/organ/O = W
		if(O.damage > round(O.maxHealth/2))
			to_chat(user, "<span class='warning'>[W] is too damaged to sell!</span>")
			return
	if(W.cost > 0)
		if(W.illegal == illegal)
			for(var/i in 1 to (W.cost / 5) * (user.social + (user.additional_social * 0.1)))
				new /obj/item/stack/dollar(loc)
			playsound(loc, 'code/modules/wod13/sounds/sell.ogg', 50, TRUE)
			if(istype(W, /obj/item/organ))
				var/mob/living/carbon/human/H = user
				to_chat(src, "<span class='userdanger'><b>Selling organs is a depraved act! If I keep doing this I will become a wight.</b></span>")
				H.AdjustHumanity(-1, 0)
			else if(istype(W, /obj/item/reagent_containers/food/drinks/meth/cocaine))
				var/mob/living/carbon/human/H = user
				H.AdjustHumanity(-1, 5)
			else if(istype(W, /obj/item/reagent_containers/food/drinks/meth))
				var/mob/living/carbon/human/H = user
				H.AdjustHumanity(-1, 4)
			else if(illegal)
				var/mob/living/carbon/human/H = user
				H.AdjustHumanity(-1, 7)
			qdel(W)
			return
	else
		..()

//Click-dragging to the vendor to mass-sell a certain type of item
//Beware, hardcoding ahead! To avoid polluting the codebase with variables that are only used in one place (here).
/obj/lombard/MouseDrop_T(obj/item/sold, mob/living/user)
	..()
	if(!istype(sold))
		return
	if(sold.illegal != illegal)
		return
	//Briefly copypasting the selling code since for now this is a separate proc compared to selling.
	if(istype(sold, /obj/item/stack))
		return
	if(user.CanReach(src)) //User is near the pawnshop/black market
		if(!user.CanReach(sold)) //User is not near the goods themselves, abandon.
			return
	else
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
	//We use this variable to determine whether a prospective seller should be notified about their humanity hit, prompting them if they're gonna lose it.
	//Also used to merge the item sales into one AdjustHumanity() proc to avoid excessive noise and chat spam
	var/humanity_penalty_limit = 0 //Set to -1 for things that can induce 0 humanity AKA wighting.
	if(istype(sold, /obj/item/organ))
		humanity_penalty_limit = -1
	else if(istype(sold, /obj/item/reagent_containers/food/drinks/meth))
		if(istype(sold, /obj/item/reagent_containers/food/drinks/meth/cocaine))
			humanity_penalty_limit = 5
		else //Meth
			humanity_penalty_limit = 4
	else if(sold.illegal)
		humanity_penalty_limit = 7
	var/list/item_list_to_sell = list() //Store this list for later, we are currently only doing a count to let the user know of their humanity hit.
	for(var/obj/item/counted_item in turf_with_items)
		if(istype(sold))
			item_list_to_sell += counted_item
	if(item_list_to_sell.len == 1) //Just one item, sell it normally
		attackby(sold, seller)
		return
	if(!seller.clane.enlightenment) //Do the prompt if the user cares about humanity. Make this check for enlightenment too if we ever add items that increase humanity when sold.
		if(humanity_penalty_limit && (humanity_penalty_limit < seller.humanity)) //Check if the user is actually at risk of losing more humanity.
			if((humanity_penalty_limit == -1) && ((user.humanity - item_list_to_sell.len) <= 0)) //User will wight out if they do this, don't offer the alert, just warn the user.
				to_chat(user, "<span class='warning'>Selling this will remove all of your Humanity!</span>")
				return
			var/choice = alert(seller, "Your HUMANITY is currently at [seller.humanity], you will LOSE [max(seller.humanity - item_list_to_sell.len, humanity_penalty_limit)] humanity if you proceed. Do you proceed?",,"Yes", "No")
			if(choice == "No")
				return
	var/organ_sale
	var/organ_sale_fail //If an organ was too damaged when mass-selling them it will announce it to the player
	for(var/obj/item/selling_item in item_list_to_sell)
		if(selling_item.loc != turf_with_items) //Item has been moved away.
			item_list_to_sell -= selling_item //Removing items from the list to leave all the items that have been sold. Empty list = no items sold.
			continue
	//TO-DO: Turn the item selling into a proc to use in both procs.
		if(istype(selling_item, /obj/item/organ))
			var/obj/item/organ/organ_to_sell = selling_item
			if(organ_to_sell.damage > round(organ_to_sell.maxHealth/2))
				organ_sale_fail = TRUE
				item_list_to_sell -= selling_item
				continue
			organ_sale = TRUE //Organ sale succeeded

		var/obj/item/stack/dollar/money_to_spawn = new(loc)
		//In case we ever add items that sell for more than the maximum amount of dollars in a stack and can be mass-sold, we use this proc. Currently unused.
		//Certainly beats doing New() on hundreds of individual instances of money.
		if(selling_item.cost >= money_to_spawn.max_amount)
			money_to_spawn.amount = money_to_spawn.max_amount
			var/extra_money_stack = selling_item.cost/money_to_spawn.max_amount - 1 //The -1 is the money already spawned
			if(extra_money_stack > 0)
				for(var/i in 1 to ceil(extra_money_stack)) //0.6 extra_money_stack = a new dollar stack, 1.3 extra_money_stack = two new dollar stacks etc.
					var/obj/item/stack/dollar/extra_money_to_spawn = new(loc)
					if(extra_money_stack >= 1)
						extra_money_to_spawn.amount = extra_money_to_spawn.max_amount
						extra_money_stack -= 1
					else
						extra_money_to_spawn.amount = extra_money_to_spawn.max_amount/extra_money_stack
					extra_money_to_spawn.update_icon_state()
		else
			money_to_spawn.amount = (selling_item.cost / 5) * (seller.social + (seller.additional_social * 0.1))
		money_to_spawn.update_icon_state()
	if(organ_sale)
		to_chat(src, "<span class='userdanger'><b>Selling organs is a depraved act! If I keep doing this I will become a wight.</b></span>")
	if(organ_sale_fail)
		to_chat(src, "<span class='warning'>At least one organ was too damaged to sell!</span>")
	if(!item_list_to_sell.len)
		return
	playsound(loc, 'code/modules/wod13/sounds/sell.ogg', 50, TRUE)
	seller.AdjustHumanity(-1 * item_list_to_sell.len, humanity_penalty_limit)
	//Leave this deletion at the very end just in case any earlier qdel would decide to hard-del the item and remove the item from the list before actually adjusting humanity and such
	for(var/item_to_delete in item_list_to_sell)
		qdel(item_to_delete)

/obj/lombard/blackmarket
	name = "black market"
	desc = "Sell illegal goods."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	icon_state = "sell_d"
	icon = 'code/modules/wod13/props.dmi'
	anchored = TRUE
	illegal = TRUE
