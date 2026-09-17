extends RefCounted
## Integer cash ledger. Spending priority: rent, food, other essentials.
## Unfunded needs are recorded, never silently converted to unlimited debt.


static func calculate(household: Dictionary, actors: Dictionary, economy: Dictionary,
		food_index: int, earned_by_actor: Dictionary) -> Dictionary:
	var income: int = 0
	var food: int = 0
	var living_members: int = 0
	for id: String in household.member_ids:
		income += int(earned_by_actor.get(id, 0))
		if actors[id].alive:
			living_members += 1
			var base_food: int = int(economy.adult_food if actors[id].age >= economy.adult_age
				else economy.child_food)
			food += int(base_food * food_index / 1000.0)
	var rent: int = int(economy.rent) if living_members > 0 else 0
	var essentials: int = living_members * int(economy.essentials_per_person)
	var planned: int = rent + food + essentials
	var opening_savings: int = int(household.savings)
	var opening_debt: int = int(household.debt)
	var interest: int = int(opening_debt * int(economy.debt_interest_basis_points) / 10000.0)
	var debt: int = opening_debt + interest
	var savings_used: int = mini(opening_savings, maxi(0, planned - income))
	var borrowed: int = mini(maxi(0, int(economy.credit_limit) - debt),
		maxi(0, planned - income - savings_used))
	var cash: int = income + savings_used + borrowed
	var rent_paid: int = mini(cash, rent)
	cash -= rent_paid
	var food_paid: int = mini(cash, food)
	cash -= food_paid
	var essentials_paid: int = mini(cash, essentials)
	cash -= essentials_paid
	var debt_repaid: int = mini(cash, debt)
	cash -= debt_repaid
	var paid: int = rent_paid + food_paid + essentials_paid
	var food_security: int = 1000 if food == 0 else int(food_paid * 1000.0 / food)
	return {
		"earned_by_actor": earned_by_actor.duplicate(true), "earned_income": income,
		"planned_expenses": planned, "rent_due": rent, "food_due": food,
		"essentials_due": essentials, "rent_paid": rent_paid, "food_paid": food_paid,
		"essentials_paid": essentials_paid, "paid_expenses": paid,
		"opening_savings": opening_savings, "savings_used": savings_used,
		"closing_savings": opening_savings - savings_used + cash,
		"opening_debt": opening_debt, "interest": interest, "borrowed": borrowed,
		"debt_repaid": debt_repaid, "closing_debt": debt + borrowed - debt_repaid,
		"budget_deficit": maxi(0, planned - income), "unmet_needs": planned - paid,
		"food_security": food_security,
		"living_standard": "destitute" if food_security < 800 else (
			"poor" if planned > income or planned > paid else "basic")
	}


static func validate_ledger(ledger: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if ledger.opening_savings + ledger.earned_income + ledger.borrowed != \
			ledger.paid_expenses + ledger.debt_repaid + ledger.closing_savings:
		errors.append("Cash ledger does not balance")
	if ledger.opening_debt + ledger.interest + ledger.borrowed - ledger.debt_repaid != ledger.closing_debt:
		errors.append("Debt ledger does not balance")
	if ledger.rent_paid + ledger.food_paid + ledger.essentials_paid != ledger.paid_expenses:
		errors.append("Expense ledger does not balance")
	if ledger.planned_expenses - ledger.paid_expenses != ledger.unmet_needs:
		errors.append("Unmet needs do not match expenses")
	var total: int = 0
	for value: int in ledger.earned_by_actor.values():
		total += value
		if value < 0:
			errors.append("Negative actor earnings")
	if total != ledger.earned_income:
		errors.append("Earned income does not match actor ledger")
	for key: String in ["opening_savings", "closing_savings", "opening_debt", "closing_debt",
			"borrowed", "debt_repaid", "unmet_needs", "interest", "earned_income",
			"planned_expenses", "paid_expenses", "rent_paid", "food_paid", "essentials_paid"]:
		if ledger[key] < 0:
			errors.append("Negative ledger field: " + key)
	return errors
