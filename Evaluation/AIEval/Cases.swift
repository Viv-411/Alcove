import Foundation

/// A receipt line and the words a correct name must contain.
/// Labels were written by hand from what each code means on a US grocery receipt.
struct ReceiptCase {
    let line: String
    let mustContain: [String]
}

let receiptCases: [ReceiptCase] = [
    .init(line: "GRN BNS 2LB", mustContain: ["green", "bean"]),
    .init(line: "AMUL PNR 200G", mustContain: ["paneer"]),
    .init(line: "ORG BANANAS", mustContain: ["organic", "banana"]),
    .init(line: "CHKN THGH BNLS", mustContain: ["chicken", "thigh", "boneless"]),
    .init(line: "KIRK OLV OIL 2L", mustContain: ["olive", "oil"]),
    .init(line: "TOM ROMA", mustContain: ["roma", "tomato"]),
    .init(line: "HLDRM ALOO BHJ", mustContain: ["aloo", "bhujia"]),
    .init(line: "LG BRN EGGS 18CT", mustContain: ["large", "brown", "egg"]),
    .init(line: "CILANTRO BUNCH", mustContain: ["cilantro"]),
    .init(line: "TOOR DAL 4LB", mustContain: ["toor", "dal"]),
    .init(line: "GV 2% MILK GAL", mustContain: ["milk"]),
    .init(line: "STRWBRY 1LB", mustContain: ["strawberry"]),
    .init(line: "BNLS SKNLS CHKN BRST", mustContain: ["boneless", "skinless", "chicken", "breast"]),
    .init(line: "YLW ONION 3LB", mustContain: ["yellow", "onion"]),
    .init(line: "RSST POTATO 5LB", mustContain: ["russet", "potato"]),
    .init(line: "SHRP CHDR CHS", mustContain: ["sharp", "cheddar", "cheese"]),
    .init(line: "GRK YGRT PLN", mustContain: ["greek", "yogurt", "plain"]),
    .init(line: "WHL WHT BREAD", mustContain: ["whole", "wheat", "bread"]),
    .init(line: "FRZ PEAS 2LB", mustContain: ["frozen", "pea"]),
    .init(line: "BSMTI RICE 10LB", mustContain: ["basmati", "rice"]),
    .init(line: "GRND CUMIN", mustContain: ["ground", "cumin"]),
    .init(line: "MNGO ALPHNSO", mustContain: ["mango", "alphonso"]),
    .init(line: "UNSLTD BTR", mustContain: ["unsalted", "butter"]),
    .init(line: "AVOCADO HASS", mustContain: ["avocado"]),
    .init(line: "SPNCH BABY 5OZ", mustContain: ["baby", "spinach"]),
    .init(line: "PNT BTR CRMY", mustContain: ["peanut", "butter", "creamy"]),
    .init(line: "GRLC PEELED", mustContain: ["garlic"]),
    .init(line: "GNGR ROOT", mustContain: ["ginger"]),
    .init(line: "CRN TORT 30CT", mustContain: ["corn", "tortilla"]),
    .init(line: "LMN EACH", mustContain: ["lemon"]),
]

/// The household items the receipt test pretends are already tracked.
let receiptHousehold = ["Paneer", "Toor Dal", "Aloo Bhujia", "Basmati Rice", "Greek Yogurt"]

/// The item names in the app's sample home (`SampleData.populate`).
let sampleHousehold = [
    "Whole Wheat Atta", "Toor Dal", "Sona Masoori Rice", "Basmati Rice", "Parle-G Biscuits", "Aloo Bhujia",
    "Moong Dal", "Frozen Parathas", "Green Peas", "Paneer", "Greek Yogurt", "Ghee", "Chana Masala",
    "Peanut Butter", "Olive Oil", "Instant Noodles",
]

// MARK: - Pantries for meal ideas

func item(_ name: String, _ quantity: Int = 1, days: Int? = nil, _ location: String = "Pantry") -> PantryItem {
    PantryItem(name: name, quantity: quantity, daysToExpiry: days, location: location)
}

/// The app's sample household: an Indian-American family that buys in bulk.
let indianPantry: [PantryItem] = [
    item("Paneer", days: 2, "Fridge"),
    item("Greek Yogurt", days: -1, "Fridge"),
    item("Aloo Bhujia", days: 5, "Kitchen cabinets"),
    item("Parle-G Biscuits", 2, days: 45, "Kitchen cabinets"),
    item("Frozen Parathas", 4, days: 90, "Freezer"),
    item("Whole Wheat Atta", 3, days: 120, "Garage"),
    item("Instant Noodles", 2, days: 150),
    item("Ghee", days: 180),
    item("Toor Dal", days: 200),
    item("Green Peas", 2, days: 200, "Freezer"),
    item("Moong Dal", 3, days: 240),
    item("Olive Oil", days: 300),
    item("Sona Masoori Rice", 2, days: 300, "Garage"),
    item("Chana Masala", 2, days: 400, "Kitchen cabinets"),
    item("Basmati Rice", 2),
]

let westernPantry: [PantryItem] = [
    item("Baby Spinach", days: 1, "Fridge"),
    item("Eggs", 10, days: 2, "Fridge"),
    item("Whole Milk", days: 3, "Fridge"),
    item("Sour Cream", days: -2, "Fridge"),
    item("Chicken Breast", 2, days: 60, "Freezer"),
    item("Spaghetti", 2),
    item("Canned Tomatoes", 3),
    item("Cheddar Cheese", days: 20, "Fridge"),
    item("Sandwich Bread", days: 5),
    item("Oreo Cookies", 2),
    item("Black Beans", 2),
    item("Yellow Onion", 3),
]

let sparsePantry: [PantryItem] = [
    item("Basmati Rice", 2),
    item("Eggs", 6, days: 9, "Fridge"),
    item("Yellow Onion", 2),
]

/// 80 items: more than the 60 the prompt can hold. The expiring cauliflower
/// sorts last alphabetically, so it only survives if the app lists urgent food first.
let largePantry: [PantryItem] = {
    let names = [
        "Almonds", "Apple Juice", "Baking Powder", "Basmati Rice", "Black Beans", "Bread Flour", "Brown Sugar",
        "Butter", "Canned Corn", "Canned Tomatoes", "Cashews", "Cheddar Cheese", "Chickpeas", "Chocolate Chips",
        "Coconut Milk", "Cornflakes", "Couscous", "Cranberry Juice", "Dark Chocolate", "Dates", "Dried Mango",
        "Egg Noodles", "Eggs", "Frozen Corn", "Frozen Parathas", "Frozen Peas", "Garlic", "Ghee", "Ginger",
        "Granola", "Green Lentils", "Green Tea", "Honey", "Jasmine Rice", "Kidney Beans", "Ketchup", "Lemon",
        "Macaroni", "Maple Syrup", "Mayonnaise", "Moong Dal", "Mozzarella", "Mustard", "Oats", "Olive Oil",
        "Orange Juice", "Paneer", "Pasta Sauce", "Peanut Butter", "Pickles", "Pita Bread", "Popcorn", "Potatoes",
        "Quinoa", "Raisins", "Red Lentils", "Red Onion", "Rice Noodles", "Salsa", "Sesame Oil", "Soy Sauce",
        "Spaghetti", "Sweet Potatoes", "Tahini", "Toor Dal", "Tortilla Chips", "Tortillas", "Tuna", "Urad Dal",
        "Vanilla Extract", "Vegetable Broth", "Walnuts", "White Vinegar", "Whole Wheat Atta", "Yellow Onion",
        "Yogurt", "Zucchini", "Bell Peppers", "Carrots",
    ]
    return names.map { item($0, days: 200) } + [item("Cauliflower", days: 1, "Fridge")]
}()

let snackNames: Set<String> = ["Parle-G Biscuits", "Aloo Bhujia", "Oreo Cookies", "Tortilla Chips", "Popcorn", "Chocolate Chips", "Dark Chocolate"]
let meatWords: Set<String> = ["chicken", "beef", "pork", "lamb", "mutton", "fish", "shrimp", "prawn", "bacon", "ham", "turkey", "sausage", "tuna", "salmon"]
