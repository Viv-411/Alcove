# Alcove AI evaluation

Generated Nov 27, 2026 at 5:34 PM on a Mac running Apple's on-device model (available). The iPhone uses the same Foundation Models framework; speeds on a phone will differ.

## Receipt names (`ReceiptAI`)

30 hand-labelled receipt lines. A name counts as correct when it contains every labelled word (for example *GRN BNS 2LB* must contain *green* and *bean*); a match to one of the household's items counts as correct when it's the right item. The **raw model** column is the model's own answer; the **app** column is what Alcove shows after its faithfulness check.

| Receipt line | Raw model | | Alcove shows | |
|---|---|---|---|---|
| `GRN BNS 2LB` | Green Beans 2lb | ✅ | Green Beans 2lb | ✅ correct |
| `AMUL PNR 200G` | Paneer 200g | ✅ | Paneer | ✅ correct |
| `ORG BANANAS` | Organic Bananas | ✅ | Organic Bananas | ✅ correct |
| `CHKN THGH BNLS` | Chicken Thigh Boneless | ✅ | Chicken Thigh Boneless | ✅ correct |
| `KIRK OLV OIL 2L` | Kirkland Signature Olive Oil 2L | ✅ | KIRK OLV OIL 2L | ↩︎ abbreviation left as is |
| `TOM ROMA` | Roma Tomatoes | ✅ | Roma Tomatoes | ✅ correct |
| `HLDRM ALOO BHJ` | Aloo Bhujia | ✅ | Aloo Bhujia | ✅ correct |
| `LG BRN EGGS 18CT` | Large Brown Eggs 18ct | ✅ | Large Brown Eggs 18ct | ✅ correct |
| `CILANTRO BUNCH` | Cilantro Bunch | ✅ | CILANTRO BUNCH | ✅ already clear |
| `TOOR DAL 4LB` | Toor Dal 4lb | ✅ | Toor Dal | ✅ correct |
| `GV 2% MILK GAL` | Great Value 2% Milk Gallon | ✅ | Great Value 2% Milk Gallon | ✅ correct |
| `STRWBRY 1LB` | Strawberry 1lb | ✅ | Strawberry 1lb | ✅ correct |
| `BNLS SKNLS CHKN BRST` | Boneless Chicken Breast | ❌ | BNLS SKNLS CHKN BRST | ↩︎ abbreviation left as is |
| `YLW ONION 3LB` | Yellow Onion 3lb | ✅ | Yellow Onion 3lb | ✅ correct |
| `RSST POTATO 5LB` | Russet Potato 5lb | ✅ | Russet Potato 5lb | ✅ correct |
| `SHRP CHDR CHS` | Sharp Cheddar Cheese | ✅ | Sharp Cheddar Cheese | ✅ correct |
| `GRK YGRT PLN` | Greek Yogurt Plain | ✅ | Greek Yogurt | ✅ correct |
| `WHL WHT BREAD` | White Whole Wheat Bread | ✅ | White Whole Wheat Bread | ✅ correct |
| `FRZ PEAS 2LB` | Frozen Peas 2lb | ✅ | Frozen Peas 2lb | ✅ correct |
| `BSMTI RICE 10LB` | Basmati Rice 10lb | ✅ | Basmati Rice | ✅ correct |
| `GRND CUMIN` | Ground Cumin | ✅ | Ground Cumin | ✅ correct |
| `MNGO ALPHNSO` | Mango Alphonso | ✅ | Mango Alphonso | ✅ correct |
| `UNSLTD BTR` | Unsalted Butter | ✅ | Unsalted Butter | ✅ correct |
| `AVOCADO HASS` | Avocado Hass | ✅ | AVOCADO HASS | ✅ already clear |
| `SPNCH BABY 5OZ` | Spinach Baby 5oz | ✅ | Spinach Baby 5oz | ✅ correct |
| `PNT BTR CRMY` | Plain Cream Cheese | ❌ | PNT BTR CRMY | ↩︎ abbreviation left as is |
| `GRLC PEELED` | Garlic Peeled | ✅ | Garlic Peeled | ✅ correct |
| `GNGR ROOT` | Ginger Root | ✅ | Ginger Root | ✅ correct |
| `CRN TORT 30CT` | Crusty Tortilla 30ct | ❌ | CRN TORT 30CT | ↩︎ abbreviation left as is |
| `LMN EACH` | Lemon Each | ✅ | Lemon Each | ✅ correct |

| | Clear, correct name shown | Wrong name shown | Abbreviation left for the person to fix |
|---|---|---|---|
| Raw model (if trusted) | 27/30 (90%) | 3/30 (10%) | 0/30 (0%) |
| Alcove (with check) | 26/30 (87%) | 0/30 (0%) | 4/30 (13%) |
| No AI (receipt text only) | 4/30 (13%) | 0/30 (0%) | 26/30 (87%) |

One request for all 30 lines took 10.1 s.

**Repeat run:** 30/30 (100%) of lines got the same result the second time.

## Whole receipt: photo → text → items → names

`AlcoveTests/Fixtures/receipt.png`, run through the same steps as the app: Vision text recognition, `ReceiptParser`, then `ReceiptAI`.

Text recognition found 17 lines; the parser kept 7 items and skipped totals, tax and payment lines.

| Parsed item | Qty | Alcove shows |
|---|---|---|
| Aash Atta 20lb | 1 | Aash Atta 20lb (unchanged) |
| Laxmi Toor Dal 4lb | 1 | Toor Dal (matched to your item) |
| Parle G 800g | 2 | Parle G |
| Haldiram Aloo Bhujia | 1 | Aloo Bhujia (matched to your item) |
| Deer Sona Masoori 20lb | 1 | Deer Sona Masoori |
| Nanak Paneer 140z | 1 | Paneer (matched to your item) |
| Maggi Noodles 12pk | 1 | Maggi Noodles |

## Meal ideas (`RecipeGenerator`)

Each run asks for 3 dishes with the app's real instructions, prompt and temperature (0.4), then applies the app's ingredient check. Expiring = good for 3 days or less.

### Sample family pantry

<details><summary>All 60 dishes</summary>

- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Vegetable Pulao (40 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Parathas, Paneer, Green Peas
- Paneer and Moong Dal Curry (40 min): from home Frozen Parathas, Paneer, Moong Dal — model listed: Frozen Parathas, Paneer, Moong Dal
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Green Peas Curry (25 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Tomato Curry (30 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer Tikka Masala (20 min): from home Paneer, Frozen Parathas, Chana Masala — model listed: Paneer, Frozen Parathas, Chana Masala
- Paneer and Vegetable Pulao (30 min): from home Paneer, Green Peas, Sona Masoori Rice, Chana Masala — model listed: Paneer, Frozen Peas, Sona Masoori Rice, Chana Masala
- Paneer and Moong Dal Curry (40 min): from home Paneer, Moong Dal, Green Peas, Chana Masala — model listed: Paneer, Moong Dal, Frozen Peas, Chana Masala
- Paneer Tikka (20 min): from home Paneer, Chana Masala — model listed: Paneer, Chana Masala, Olive Oil
- Paneer and Paratha (30 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Parathas, Olive Oil
- Paneer and Rice (30 min): from home Paneer, Sona Masoori Rice — model listed: Paneer, Sona Masoori Rice, Olive Oil
- Paneer Paratha (15 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Tomato Curry (20 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer and Vegetable Pulao (25 min): from home Paneer, Green Peas, Sona Masoori Rice — model listed: Paneer, Green Peas, Sona Masoori Rice
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Pulao (40 min): from home Paneer, Green Peas, Whole Wheat Atta — model listed: Paneer, Frozen Peas, Whole Wheat Atta, Olive Oil
- Paneer and Moong Dal Curry (30 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Green Peas Curry (25 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Tomato Masala (30 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Green Pea Curry (25 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Tomato Masala (20 min): from home Paneer, Frozen Parathas; to buy Tomato — model listed: Paneer, Frozen Paratha, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer Curry (30 min): from home Paneer, Green Peas — model listed: Paneer, Frozen Peas
- Paneer and Tomato Masala (25 min): from home Paneer; to buy Tomato — model listed: Paneer, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer, Olive Oil
- Paneer and Pea Curry (25 min): from home Frozen Parathas, Paneer, Green Peas, Chana Masala — model listed: Frozen Paratha, Paneer, Green Peas, Chana Masala
- Paneer and Rice (15 min): from home Frozen Parathas, Paneer, Sona Masoori Rice — model listed: Frozen Paratha, Paneer, Sona Masoori Rice, Olive Oil
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Stir Fry (25 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Paratha, Paneer, Frozen Peas
- Paneer and Tomato Curry (30 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Paratha, Paneer, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Vegetable Pulao (40 min): from home Paneer, Green Peas, Whole Wheat Atta, Sona Masoori Rice — model listed: Paneer, Green Peas, Whole Wheat Atta, Sona Masoori Rice, Olive Oil
- Paneer and Tomato Curry (30 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer Paratha (20 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Paratha
- Paneer and Vegetable Pulao (40 min): from home Paneer, Green Peas, Whole Wheat Atta, Sona Masoori Rice — model listed: Paneer, Frozen Peas, Whole Wheat Atta, Sona Masoori Rice
- Paneer and Toor Dal Curry (30 min): from home Paneer, Toor Dal, Green Peas, Chana Masala — model listed: Paneer, Toor Dal, Frozen Peas, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Tomato Curry (40 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer and Green Peas Stir-fry (15 min): from home Paneer, Green Peas — model listed: Paneer, Green Peas, Olive Oil
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Tomato Masala (25 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer and Green Pea Curry (20 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Vegetable Stir-fry (15 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Parathas, Paneer, Green Peas
- Paneer and Tomato Curry (25 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Parathas, Paneer, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Vegetable Stir Fry (15 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Parathas, Paneer, Green Peas
- Paneer and Toor Dal Soup (30 min): from home Frozen Parathas, Paneer, Toor Dal — model listed: Frozen Parathas, Paneer, Toor Dal
- Paneer Tikka Masala (30 min): from home Paneer, Frozen Parathas, Chana Masala — model listed: Paneer, Frozen Parathas, Chana Masala
- Paneer and Vegetable Pulao (45 min): from home Paneer, Green Peas, Sona Masoori Rice — model listed: Paneer, Frozen Peas, Sona Masoori Rice
- Paneer and Tomato Curry (30 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Green Pea Curry (25 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Moong Dal Stew (30 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala
- Paneer Paratha (30 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Green Pea Curry (20 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Tomato Masala (25 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala

</details>

### Different household

<details><summary>All 15 dishes</summary>

- Spinach and Cheese Omelette (10 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Spinach and Tomato Soup (20 min): from home Baby Spinach, Canned Tomatoes, Yellow Onion — model listed: Baby Spinach, Canned Tomatoes, Yellow Onion
- Milk and Cheese Pancakes (15 min): from home Eggs, Whole Milk, Cheddar Cheese — model listed: Eggs, Whole Milk, Cheddar Cheese
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Spinach and Milk Pancakes (20 min): from home Eggs, Whole Milk, Baby Spinach — model listed: Eggs, Whole Milk, Baby Spinach
- Spinach and Cheese Quesadillas (10 min): from home Eggs, Baby Spinach, Cheddar Cheese, Sandwich Bread — model listed: Eggs, Baby Spinach, Cheddar Cheese, Sandwich Bread
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Whole Milk Pancakes (20 min): from home Eggs, Whole Milk, Sandwich Bread — model listed: Eggs, Whole Milk, Sandwich Bread
- Chicken and Spinach Stir Fry (25 min): from home Chicken Breast, Baby Spinach, Yellow Onion — model listed: Chicken Breast, Baby Spinach, Yellow Onion
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Egg Fried Rice (20 min): from home Eggs, Yellow Onion, Canned Tomatoes — model listed: Eggs, Yellow Onion, Canned Tomatoes
- Spinach and Cheese Sandwich (10 min): from home Eggs, Baby Spinach, Sandwich Bread, Cheddar Cheese — model listed: Eggs, Baby Spinach, Sandwich Bread, Cheddar Cheese
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Creamy Spinach Soup (20 min): from home Baby Spinach, Whole Milk, Cheddar Cheese — model listed: Baby Spinach, Whole Milk, Cheddar Cheese
- Egg and Cheese Sandwich (10 min): from home Eggs, Sandwich Bread, Cheddar Cheese — model listed: Eggs, Sandwich Bread, Cheddar Cheese

</details>

### Vegetarian request with chicken in the freezer

<details><summary>All 15 dishes</summary>

- Egg Fried Spinach (15 min): from home Baby Spinach, Eggs — model listed: Baby Spinach, Eggs
- Spinach and Cheese Sandwich (10 min): from home Baby Spinach, Cheddar Cheese, Sandwich Bread — model listed: Baby Spinach, Cheddar Cheese, Sandwich Bread
- Spinach and Milk Smoothie (5 min): from home Baby Spinach, Whole Milk — model listed: Baby Spinach, Whole Milk
- Spinach and Cheese Omelette (10 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Spinach and Cheese Sandwich (15 min): from home Eggs, Baby Spinach, Sandwich Bread, Cheddar Cheese — model listed: Eggs, Baby Spinach, Sandwich Bread, Cheddar Cheese
- Cheesy Spinach Soup (20 min): from home Eggs, Baby Spinach, Cheddar Cheese, Whole Milk — model listed: Eggs, Baby Spinach, Cheddar Cheese, Whole Milk
- Spinach and Cheese Omelette (10 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Milk and Cheese Toast (15 min): from home Whole Milk, Sandwich Bread, Cheddar Cheese — model listed: Whole Milk, Sandwich Bread, Cheddar Cheese
- Egg and Spinach Sandwich (10 min): from home Eggs, Baby Spinach, Whole Milk — model listed: Eggs, Baby Spinach, Whole Milk
- Spinach and Egg Omelette (10 min): from home Eggs, Baby Spinach — model listed: Eggs, Baby Spinach
- Milk and Cheese Toast (5 min): from home Whole Milk, Cheddar Cheese, Sandwich Bread — model listed: Whole Milk, Cheddar Cheese, Sandwich Bread
- Egg and Spinach Sandwich (10 min): from home Eggs, Baby Spinach, Sandwich Bread — model listed: Eggs, Baby Spinach, Sandwich Bread
- Spinach and Cheese Omelette (20 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Milk and Egg Custard (40 min): from home Eggs, Whole Milk — model listed: Eggs, Whole Milk
- Spinach and Cheese Sandwich (10 min): from home Baby Spinach, Sandwich Bread, Cheddar Cheese — model listed: Baby Spinach, Sandwich Bread, Cheddar Cheese

</details>

### Under 20 minutes

<details><summary>All 14 dishes</summary>

- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Green Pea Curry (20 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Moong Dal Stew (20 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Pulao (20 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Paratha, Paneer, Green Peas
- Paneer and Tomato Masala (20 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Paratha, Paneer, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Tomato Curry (20 min): from home Paneer; to buy Tomato — model listed: Paneer, Tomato, Olive Oil
- Paneer and Green Peas Stir Fry (20 min): from home Paneer, Green Peas — model listed: Paneer, Green Peas, Olive Oil
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Peas Curry (20 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Moong Dal Stew (20 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala
- Paneer Paratha (20 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Paratha
- Paneer and Moong Dal Curry (20 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala

</details>

### Large pantry

<details><summary>All 15 dishes</summary>

- Cauliflower Rice (10 min): from home Cauliflower; to buy Dry Spices — model listed: Cauliflower, Salt, Oil, Water, Dry Spices
- Cauliflower and Cheese Quesadillas (15 min): from home Cauliflower, Cheddar Cheese; to buy Dry Spices — model listed: Cauliflower, Cheese, Salt, Oil, Water, Dry Spices
- Cauliflower and Potato Curry (20 min): from home Cauliflower, Potatoes; to buy Dry Spices — model listed: Cauliflower, Potatoes, Salt, Oil, Water, Dry Spices
- Cauliflower Rice (15 min): from home Cauliflower, Garlic — model listed: Cauliflower, Salt, Olive Oil, Garlic
- Cauliflower Fried Rice (20 min): from home Cauliflower, Egg Noodles, Garlic — model listed: Cauliflower, Eggs, Salt, Olive Oil, Garlic
- Cauliflower Curry (25 min): from home Cauliflower, Butter, Garlic, Ginger, Canned Tomatoes — model listed: Cauliflower, Butter, Salt, Olive Oil, Garlic, Ginger, Canned Tomatoes
- Cauliflower Fried Rice (15 min): from home Cauliflower, Basmati Rice, Egg Noodles; to buy Green Onion — model listed: Cauliflower, Basmati Rice, Eggs, Green Onion, Salt
- Cauliflower and Cheese Quesadillas (20 min): from home Cauliflower, Cheddar Cheese, Pita Bread — model listed: Cauliflower, Cheese, Pita Bread, Salt
- Cauliflower and Tomato Soup (25 min): from home Cauliflower, Canned Tomatoes, Garlic — model listed: Cauliflower, Tomatoes, Garlic, Olive Oil, Salt
- Cauliflower Fried Rice (20 min): from home Cauliflower, Egg Noodles, Basmati Rice — model listed: Cauliflower, Eggs, Rice, Salt, Oil, Spices
- Almond Butter and Banana Pancakes (10 min): from home Almonds, Bread Flour; to buy Bananas — model listed: Almonds, Bananas, Flour, Salt, Oil, Spices
- Butter and Sugar Cornbread (25 min): from home Butter, Bread Flour; to buy Cornmeal — model listed: Butter, Sugar, Cornmeal, Flour, Salt, Oil, Spices
- Cauliflower Fried Rice (20 min): from home Cauliflower, Egg Noodles, Soy Sauce — model listed: Cauliflower, Eggs, Soy Sauce
- Cauliflower and Almond Salad (10 min): from home Cauliflower, Almonds, Lemon — model listed: Cauliflower, Almonds, Lemon
- Cauliflower and Potato Curry (25 min): from home Cauliflower, Potatoes, Coconut Milk — model listed: Cauliflower, Potatoes, Coconut Milk

</details>

### Sparse pantry

<details><summary>All 9 dishes</summary>

- Egg Fried Rice (20 min): from home Eggs, Basmati Rice, Yellow Onion — model listed: Eggs, Rice, Yellow Onion
- Vegetable Omelette (15 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Onion and Egg Salad (10 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Scrambled Eggs (10 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Rice Pudding (20 min): from home Basmati Rice, Yellow Onion — model listed: Basmati Rice, Yellow Onion
- Vegetable Stir Fry (15 min): from home Yellow Onion, Eggs — model listed: Yellow Onion, Eggs
- Egg Fried Rice (15 min): from home Eggs, Basmati Rice — model listed: Eggs, Basmati Rice
- Egg Omelette (10 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Vegetable Omelette (10 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion

</details>

### Summary

| Scenario | Runs | Failed | Dishes shown | Runs using expiring food | Expired food shown as "from home" | Snack used as an ingredient | Meat dishes (model → shown) | Over 20 min (model → shown) | Avg time |
|---|---|---|---|---|---|---|---|---|---|
| Sample family pantry (15 items, paneer expiring, yogurt expired) | 20 | 0 | 60 | 20/20 | 0 | 0 | 0 → 0 | 34 → 34 | 4.6 s |
| Different household (12 items, spinach/eggs/milk expiring) | 5 | 0 | 15 | 5/5 | 0 | 0 | 1 → 1 | 1 → 1 | 3.7 s |
| Vegetarian request, chicken at home | 5 | 0 | 15 | 5/5 | 0 | 0 | 0 → 0 | 1 → 1 | 3.9 s |
| Under 20 minutes request | 5 | 0 | 14 | 5/5 | 0 | 0 | 0 → 0 | 1 → 0 | 4.3 s |
| Large pantry (81 items, expiring item sorts last A–Z) | 5 | 0 | 15 | 5/5 | 0 | 0 | 0 → 0 | 4 → 4 | 6.3 s |
| Sparse pantry (3 items) | 3 | 0 | 9 | n/a (none expiring) | 0 | 0 | 0 → 0 | 0 → 0 | 3.6 s |

## Comparison: first design vs. shipped design

20 runs each on the sample family pantry.

| Design | Dishes | Uses expired yogurt | Snack used as an ingredient | "From home" items that aren't at home |
|---|---|---|---|---|
| First: model decides what's at home, expired food listed, temperature 0.7 | 60 | 5 | 17 | 27 of 174 |
| Shipped: app decides what's at home, expired food left out, tuned instructions, temperature 0.4 | 60 | 0 | 0 | 0 (by design) |

