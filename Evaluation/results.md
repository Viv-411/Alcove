# Alcove AI evaluation

Generated Nov 26, 2026 at 8:52 PM on a Mac running Apple's on-device model (available). The iPhone uses the same Foundation Models framework; speeds on a phone will differ.

## Receipt names (`ReceiptAI`)

30 hand-labelled receipt lines. A name counts as correct when it contains every labelled word (for example *GRN BNS 2LB* must contain *green* and *bean*). The **raw model** column is the model's own answer; the **app** column is what Alcove shows after its faithfulness check.

| Receipt line | Raw model | | Alcove shows | |
|---|---|---|---|---|
| `GRN BNS 2LB` | Green Beans 2lb | ✅ | Green Beans 2lb | ✅ correct |
| `AMUL PNR 200G` | Paneer 200g | ✅ | AMUL PNR 200G | ↩︎ abbreviation left as is |
| `ORG BANANAS` | Organic Bananas | ✅ | Organic Bananas | ✅ correct |
| `CHKN THGH BNLS` | Chicken Thigh Boneless | ✅ | Chicken Thigh Boneless | ✅ correct |
| `KIRK OLV OIL 2L` | Kirkland Olive Oil 2L | ✅ | Kirkland Olive Oil 2L | ✅ correct |
| `TOM ROMA` | Tomato Roma | ✅ | Tomato Roma | ✅ correct |
| `HLDRM ALOO BHJ` | Aloo Bhaji | ❌ | HLDRM ALOO BHJ | ↩︎ abbreviation left as is |
| `LG BRN EGGS 18CT` | Large Brown Eggs 18ct | ✅ | Large Brown Eggs 18ct | ✅ correct |
| `CILANTRO BUNCH` | Cilantro Bunch | ✅ | CILANTRO BUNCH | ✅ already clear |
| `TOOR DAL 4LB` | Toor Dal 4lb | ✅ | TOOR DAL 4LB | ✅ already clear |
| `GV 2% MILK GAL` | 2% Milk Gallon | ✅ | GV 2% MILK GAL | ✅ already clear |
| `STRWBRY 1LB` | Strawberry 1lb | ✅ | Strawberry 1lb | ✅ correct |
| `BNLS SKNLS CHKN BRST` | Boneless Chicken Breast | ❌ | BNLS SKNLS CHKN BRST | ↩︎ abbreviation left as is |
| `YLW ONION 3LB` | Yellow Onion 3lb | ✅ | Yellow Onion 3lb | ✅ correct |
| `RSST POTATO 5LB` | Russet Potato 5lb | ✅ | Russet Potato 5lb | ✅ correct |
| `SHRP CHDR CHS` | Sharp Cheddar Cheese | ✅ | Sharp Cheddar Cheese | ✅ correct |
| `GRK YGRT PLN` | Greek Yogurt Plain | ✅ | Greek Yogurt Plain | ✅ correct |
| `WHL WHT BREAD` | White Whole Wheat Bread | ✅ | White Whole Wheat Bread | ✅ correct |
| `FRZ PEAS 2LB` | Frozen Peas 2lb | ✅ | Frozen Peas 2lb | ✅ correct |
| `BSMTI RICE 10LB` | Basmati Rice 10lb | ✅ | Basmati Rice 10lb | ✅ correct |
| `GRND CUMIN` | Ground Cumin | ✅ | Ground Cumin | ✅ correct |
| `MNGO ALPHNSO` | Mango Alphonso | ✅ | Mango Alphonso | ✅ correct |
| `UNSLTD BTR` | Unsalted Butter | ✅ | Unsalted Butter | ✅ correct |
| `AVOCADO HASS` | Avocado Hass | ✅ | AVOCADO HASS | ✅ already clear |
| `SPNCH BABY 5OZ` | Spinach Baby 5oz | ✅ | Spinach Baby 5oz | ✅ correct |
| `PNT BTR CRMY` | Plain Butter Cream | ❌ | PNT BTR CRMY | ↩︎ abbreviation left as is |
| `GRLC PEELED` | Garlic Peeled | ✅ | Garlic Peeled | ✅ correct |
| `GNGR ROOT` | Ginger Root | ✅ | Ginger Root | ✅ correct |
| `CRN TORT 30CT` | Crusty Tortilla 30ct | ❌ | CRN TORT 30CT | ↩︎ abbreviation left as is |
| `LMN EACH` | Lemon Each | ✅ | Lemon Each | ✅ correct |

| | Clear, correct name shown | Wrong name shown | Abbreviation left for the person to fix |
|---|---|---|---|
| Raw model (if trusted) | 26/30 (87%) | 4/30 (13%) | 0/30 (0%) |
| Alcove (with check) | 25/30 (83%) | 0/30 (0%) | 5/30 (17%) |
| No AI (receipt text only) | 4/30 (13%) | 0/30 (0%) | 26/30 (87%) |

One request for all 30 lines took 10.9 s.

**Repeat run:** 30/30 (100%) of lines got the same result the second time.

## Whole receipt: photo → text → items → names

`AlcoveTests/Fixtures/receipt.png`, run through the same steps as the app: Vision text recognition, `ReceiptParser`, then `ReceiptAI`.

Text recognition found 17 lines; the parser kept 7 items and skipped totals, tax and payment lines.

| Parsed item | Qty | Alcove shows |
|---|---|---|
| Aash Atta 20lb | 1 | Aash Atta 20lb (unchanged) |
| Laxmi Toor Dal 4lb | 1 | Laxmi Toor Dal 4lb (unchanged) |
| Parle G 800g | 2 | Parle G 800g (unchanged) |
| Haldiram Aloo Bhujia | 1 | Haldiram Aloo Bhujia (unchanged) |
| Deer Sona Masoori 20lb | 1 | Deer Sona Masoori 20lb (unchanged) |
| Nanak Paneer 140z | 1 | Nanak Paneer 140z (unchanged) |
| Maggi Noodles 12pk | 1 | Maggi Noodles 12pk (unchanged) |

## Meal ideas (`RecipeGenerator`)

Each run asks for 3 dishes with the app's real instructions, prompt and temperature (0.4), then applies the app's ingredient check. Expiring = good for 3 days or less.

### Sample family pantry

<details><summary>All 60 dishes</summary>

- Paneer Tikka Masala (20 min): from home Paneer, Frozen Parathas, Chana Masala — model listed: Paneer, Frozen Parathas, Chana Masala
- Paneer and Vegetable Pulao (30 min): from home Paneer, Green Peas, Sona Masoori Rice — model listed: Paneer, Green Peas, Sona Masoori Rice
- Paneer and Tomato Curry (20 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer, Olive Oil
- Paneer Jeera Rice (25 min): from home Paneer, Whole Wheat Atta, Chana Masala — model listed: Paneer, Whole Wheat Atta, Olive Oil, Chana Masala, Salt
- Paneer and Green Pea Curry (20 min): from home Paneer, Green Peas — model listed: Paneer, Frozen Green Peas, Olive Oil, Salt
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Stir Fry (15 min): from home Paneer, Green Peas — model listed: Paneer, Frozen Peas, Olive Oil
- Paneer and Tomato Curry (25 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer Tikka Masala (20 min): from home Paneer, Frozen Parathas, Chana Masala — model listed: Paneer, Frozen Parathas, Chana Masala
- Paneer and Moong Dal Curry (25 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala
- Paneer and Green Pea Pulao (20 min): from home Paneer, Green Peas, Sona Masoori Rice — model listed: Paneer, Green Peas, Sona Masoori Rice
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Peas Curry (30 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Rice (20 min): from home Paneer, Sona Masoori Rice — model listed: Paneer, Sona Masoori Rice
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Vegetable Pulao (40 min): from home Frozen Parathas, Paneer, Sona Masoori Rice — model listed: Frozen Parathas, Paneer, Sona Masoori Rice
- Paneer and Tomato Curry (25 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Parathas, Paneer, Tomato
- Paneer Paratha (15 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Parathas
- Paneer Masala (20 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Frozen Peas, Chana Masala
- Paneer and Tomato Curry (15 min): from home Paneer; to buy Frozen Tomatoes — model listed: Paneer, Frozen Tomatoes, Olive Oil
- Paneer Paratha (15 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Tomato Curry (20 min): from home Paneer; to buy Tomato — model listed: Paneer, Tomato, Olive Oil
- Paneer and Green Peas Stir Fry (10 min): from home Paneer, Green Peas — model listed: Paneer, Green Peas, Olive Oil
- Paneer Paratha (20 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Paratha
- Paneer and Peas Curry (25 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Rice (20 min): from home Paneer, Sona Masoori Rice — model listed: Paneer, Sona Masoori Rice
- Paneer Paratha (20 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Paratha
- Paneer and Tomato Curry (25 min): from home Paneer, Frozen Parathas; to buy Tomato — model listed: Paneer, Frozen Paratha, Tomato
- Paneer and Peas Curry (20 min): from home Paneer, Frozen Parathas, Green Peas — model listed: Paneer, Frozen Paratha, Green Peas
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Green Pea Curry (25 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Paratha, Paneer, Green Peas
- Paneer and Tomato Masala (15 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Paratha, Paneer, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Stir Fry (15 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Paratha, Paneer, Green Peas
- Paneer and Tomato Curry (20 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Paratha, Paneer, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Green Peas Curry (30 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Moong Dal Stew (40 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Pea Curry (25 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Rice (15 min): from home Paneer, Sona Masoori Rice — model listed: Paneer, Sona Masoori Rice
- Paneer Paratha (40 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Paratha
- Paneer and Vegetable Stir Fry (20 min): from home Paneer, Green Peas, Frozen Parathas — model listed: Paneer, Frozen Peas, Frozen Paratha
- Paneer and Rice (20 min): from home Paneer, Sona Masoori Rice — model listed: Paneer, Sona Masoori Rice
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer Curry (25 min): from home Paneer, Green Peas — model listed: Paneer, Frozen Peas
- Paneer and Vegetable Pulao (30 min): from home Paneer, Green Peas — model listed: Paneer, Frozen Peas
- Paneer Paratha (20 min): from home Paneer, Frozen Parathas — model listed: Paneer, Frozen Parathas
- Paneer and Vegetable Pulao (30 min): from home Paneer, Sona Masoori Rice; to buy Frozen Vegetables — model listed: Paneer, Frozen Vegetables, Sona Masoori Rice
- Paneer and Green Peas Curry (20 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Pulao (40 min): from home Paneer, Green Peas, Sona Masoori Rice — model listed: Paneer, Green Peas, Sona Masoori Rice, Olive Oil
- Paneer and Moong Dal Curry (30 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala, Olive Oil
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Stir Fry (15 min): from home Frozen Parathas, Paneer, Green Peas — model listed: Frozen Paratha, Paneer, Green Peas
- Paneer and Tomato Curry (20 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Paratha, Paneer, Tomato
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Green Pea Curry (30 min): from home Paneer, Green Peas, Chana Masala — model listed: Paneer, Green Peas, Chana Masala
- Paneer and Moong Dal Stew (40 min): from home Paneer, Moong Dal, Chana Masala — model listed: Paneer, Moong Dal, Chana Masala

</details>

### Different household

<details><summary>All 15 dishes</summary>

- Eggs Benedict (20 min): from home Eggs, Whole Milk, Sandwich Bread, Cheddar Cheese — model listed: Eggs, Whole Milk, Sandwich Bread, Cheddar Cheese
- Spinach and Cheese Omelette (10 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Cheese and Tomato Soup (20 min): from home Whole Milk, Canned Tomatoes, Cheddar Cheese — model listed: Whole Milk, Canned Tomatoes, Cheddar Cheese
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Whole Milk Pancakes (20 min): from home Eggs, Whole Milk, Sandwich Bread — model listed: Eggs, Whole Milk, Sandwich Bread
- Cheese and Bean Sandwich (10 min): from home Eggs, Whole Milk, Black Beans, Sandwich Bread — model listed: Eggs, Whole Milk, Black Beans, Sandwich Bread
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Milk and Egg Pancakes (20 min): from home Eggs, Whole Milk — model listed: Eggs, Whole Milk
- Spinach and Cheese Sandwich (10 min): from home Sandwich Bread, Baby Spinach, Cheddar Cheese — model listed: Sandwich Bread, Baby Spinach, Cheddar Cheese
- Spinach and Cheese Omelette (10 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Milk and Egg Pancakes (15 min): from home Eggs, Whole Milk — model listed: Eggs, Whole Milk
- Egg and Spinach Sandwich (10 min): from home Eggs, Baby Spinach, Sandwich Bread — model listed: Eggs, Baby Spinach, Sandwich Bread
- Spinach and Cheese Omelette (15 min): from home Baby Spinach, Cheddar Cheese — model listed: Baby Spinach, Cheddar Cheese
- Egg Fried Rice (10 min): from home Eggs, Spaghetti — model listed: Eggs, Spaghetti
- Milk and Cheese Pancakes (10 min): from home Whole Milk, Cheddar Cheese — model listed: Whole Milk, Cheddar Cheese

</details>

### Vegetarian request with chicken in the freezer

<details><summary>All 15 dishes</summary>

- Spinach and Egg Scramble (15 min): from home Baby Spinach, Eggs — model listed: Baby Spinach, Eggs
- Whole Milk Pancakes (20 min): from home Whole Milk, Eggs — model listed: Whole Milk, Eggs
- Cheese and Spinach Quesadillas (10 min): from home Baby Spinach, Cheddar Cheese — model listed: Baby Spinach, Cheddar Cheese
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Egg Fried Rice (20 min): from home Eggs, Yellow Onion, Canned Tomatoes — model listed: Eggs, Yellow Onion, Canned Tomatoes
- Spinach and Cheese Quesadillas (10 min): from home Eggs, Baby Spinach, Sandwich Bread — model listed: Eggs, Baby Spinach, Sandwich Bread
- Spinach and Cheese Omelette (15 min): from home Eggs, Baby Spinach, Cheddar Cheese — model listed: Eggs, Baby Spinach, Cheddar Cheese
- Whole Milk Pancakes (20 min): from home Whole Milk, Eggs, Sandwich Bread — model listed: Whole Milk, Eggs, Sandwich Bread
- Egg and Cheese Sandwich (10 min): from home Eggs, Whole Milk, Sandwich Bread — model listed: Eggs, Whole Milk, Sandwich Bread
- Egg Fried Spinach (10 min): from home Baby Spinach, Eggs — model listed: Baby Spinach, Eggs
- Spinach and Cheese Omelette (15 min): from home Baby Spinach, Eggs, Cheddar Cheese — model listed: Baby Spinach, Eggs, Cheddar Cheese
- Spinach and Milk Rice (20 min): from home Baby Spinach, Whole Milk; to buy Rice — model listed: Baby Spinach, Whole Milk, Rice
- Egg Fried Spinach (15 min): from home Baby Spinach, Eggs — model listed: Baby Spinach, Eggs
- Spinach and Cheese Omelette (20 min): from home Baby Spinach, Eggs, Cheddar Cheese — model listed: Baby Spinach, Eggs, Cheddar Cheese
- Milk and Spinach Soup (30 min): from home Baby Spinach, Whole Milk — model listed: Baby Spinach, Whole Milk

</details>

### Under 20 minutes

<details><summary>All 12 dishes</summary>

- Paneer Tikka Masala (20 min): from home Paneer, Frozen Parathas, Chana Masala; to buy Tomato — model listed: Paneer, Frozen Parathas, Tomato, Chana Masala
- Paneer and Green Peas Curry (20 min): from home Paneer, Green Peas, Chana Masala; to buy Tomato — model listed: Paneer, Green Peas, Tomato, Chana Masala
- Paneer and Moong Dal Stew (20 min): from home Paneer, Moong Dal, Chana Masala; to buy Tomato — model listed: Paneer, Moong Dal, Tomato, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Vegetable Pulao (20 min): from home Frozen Parathas, Paneer, Sona Masoori Rice — model listed: Frozen Paratha, Paneer, Sona Masoori Rice
- Paneer and Tomato Curry (20 min): from home Frozen Parathas, Paneer; to buy Tomato — model listed: Frozen Paratha, Paneer, Tomato
- Paneer and Vegetable Stir Fry (20 min): from home Paneer, Green Peas, Frozen Parathas — model listed: Paneer, Green Peas, Frozen Parathas, Olive Oil, Salt
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Paratha, Paneer
- Paneer and Tomato Curry (20 min): from home Paneer, Chana Masala; to buy Tomato — model listed: Paneer, Tomato, Chana Masala
- Paneer Paratha (20 min): from home Frozen Parathas, Paneer — model listed: Frozen Parathas, Paneer
- Paneer and Tomato Curry (20 min): from home Paneer, Frozen Parathas; to buy Tomato — model listed: Paneer, Frozen Parathas, Tomato
- Paneer and Green Peas (20 min): from home Paneer, Green Peas — model listed: Paneer, Green Peas

</details>

### Large pantry

<details><summary>All 15 dishes</summary>

- Cauliflower Fried Rice (20 min): from home Cauliflower, Basmati Rice, Egg Noodles; to buy Green Onion — model listed: Cauliflower, Basmati Rice, Eggs, Green Onion, Salt
- Cauliflower and Potato Curry (30 min): from home Cauliflower, Potatoes, Red Onion, Garlic, Ginger, Canned Tomatoes — model listed: Cauliflower, Potatoes, Onion, Garlic, Ginger, Canned Tomatoes, Salt
- Cauliflower and Almond Salad (10 min): from home Cauliflower, Almonds, Lemon — model listed: Cauliflower, Almonds, Lemon, Olive Oil, Salt
- Cauliflower Rice (10 min): from home Cauliflower, Butter — model listed: Cauliflower, Butter, Salt
- Cauliflower and Cheese Quesadillas (15 min): from home Cauliflower, Cheddar Cheese, Butter — model listed: Cauliflower, Cheese, Butter, Salt
- Cauliflower and Tomato Soup (20 min): from home Cauliflower, Canned Tomatoes, Butter — model listed: Cauliflower, Tomatoes, Butter, Salt
- Cauliflower Fried Rice (20 min): from home Cauliflower, Egg Noodles, Bread Flour, Butter, Rice Noodles — model listed: Cauliflower, Eggs, Bread Flour, Butter, Rice Noodles
- Cauliflower and Cheese Quesadillas (15 min): from home Cauliflower, Cheddar Cheese, Pita Bread — model listed: Cauliflower, Cheese, Pita Bread, Olive Oil
- Cauliflower and Almond Curry (25 min): from home Cauliflower, Almonds, Butter, Canned Tomatoes, Basmati Rice — model listed: Cauliflower, Almonds, Butter, Canned Tomatoes, Rice
- Cauliflower Rice (10 min): from home Cauliflower, Butter, Baking Powder — model listed: Cauliflower, Butter, Baking Powder
- Cauliflower and Almond Stir-Fry (15 min): from home Cauliflower, Almonds, Bell Peppers, Garlic — model listed: Cauliflower, Almonds, Bell Peppers, Garlic
- Cauliflower and Potato Hash (20 min): from home Cauliflower, Potatoes, Butter — model listed: Cauliflower, Potatoes, Butter
- Cauliflower Fried Rice (20 min): from home Cauliflower, Basmati Rice, Egg Noodles; to buy Green Onion — model listed: Cauliflower, Basmati Rice, Eggs, Green Onion, Salt, Oil
- Cauliflower and Peanut Butter Stir-fry (15 min): from home Cauliflower, Peanut Butter, Garlic, Soy Sauce — model listed: Cauliflower, Peanut Butter, Garlic, Soy Sauce, Salt, Oil
- Cauliflower and Cheese Quesadillas (10 min): from home Cauliflower, Cheddar Cheese, Bread Flour, Egg Noodles — model listed: Cauliflower, Cheese, Bread Flour, Eggs, Salt, Oil

</details>

### Sparse pantry

<details><summary>All 9 dishes</summary>

- Eggs Benedict (30 min): from home Eggs; to buy Bread, Ham — model listed: Eggs, Bread, Ham
- Vegetable Omelette (20 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Baked Potatoes (40 min): from home Basmati Rice, Yellow Onion — model listed: Basmati Rice, Yellow Onion
- Eggs Benedict (20 min): from home Eggs; to buy Ham, English Muffins — model listed: Eggs, Ham, English Muffins
- Vegetable Fried Rice (15 min): from home Yellow Onion, Basmati Rice — model listed: Yellow Onion, Basmati Rice
- Omelette (10 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Scrambled Eggs (10 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Vegetable Omelette (15 min): from home Eggs, Yellow Onion — model listed: Eggs, Yellow Onion
- Rice and Beans (20 min): from home Basmati Rice, Yellow Onion — model listed: Basmati Rice, Yellow Onion

</details>

### Summary

| Scenario | Runs | Failed | Dishes shown | Runs using expiring food | Expired food shown as "from home" | Snack used as an ingredient | Meat dishes (model → shown) | Over 20 min (model → shown) | Avg time |
|---|---|---|---|---|---|---|---|---|---|
| Sample family pantry (15 items, paneer expiring, yogurt expired) | 20 | 0 | 60 | 20/20 | 0 | 0 | 0 → 0 | 21 → 21 | 4.7 s |
| Different household (12 items, spinach/eggs/milk expiring) | 5 | 0 | 15 | 5/5 | 0 | 0 | 0 → 0 | 0 → 0 | 4.0 s |
| Vegetarian request, chicken at home | 5 | 0 | 15 | 5/5 | 0 | 0 | 0 → 0 | 1 → 1 | 4.5 s |
| Under 20 minutes request | 5 | 0 | 12 | 5/5 | 0 | 0 | 0 → 0 | 3 → 0 | 4.6 s |
| Large pantry (81 items, expiring item sorts last A–Z) | 5 | 0 | 15 | 5/5 | 0 | 0 | 0 → 0 | 2 → 2 | 5.5 s |
| Sparse pantry (3 items) | 3 | 0 | 9 | n/a (none expiring) | 0 | 0 | 2 → 2 | 2 → 2 | 4.6 s |

## Comparison: first design vs. shipped design

20 runs each on the sample family pantry.

| Design | Dishes | Uses expired yogurt | Snack used as an ingredient | "From home" items that aren't at home |
|---|---|---|---|---|
| First: model decides what's at home, expired food listed, temperature 0.7 | 60 | 8 | 15 | 7 of 144 |
| Shipped: app decides what's at home, expired food left out, tuned instructions, temperature 0.4 | 60 | 0 | 0 | 0 (by design) |

