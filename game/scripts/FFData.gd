extends RefCounted
class_name FFData

const RESOURCE_ORDER := [
    "Raw Food", "Cooked Food", "Dirty Water", "Clean Water",
    "Wood", "Scrap Metal", "Cloth", "Plastic", "Hardware",
    "Medicine", "Ammo", "Seeds"
]

const STARTING_RESOURCES := {
    "Raw Food": 0,
    "Cooked Food": 2,
    "Dirty Water": 0,
    "Clean Water": 2,
    "Wood": 0,
    "Scrap Metal": 0,
    "Cloth": 0,
    "Plastic": 0,
    "Hardware": 0,
    "Medicine": 0,
    "Ammo": 0,
    "Seeds": 0,
}

const BACKGROUNDS := {
    "Warehouse Worker": {"Scavenging": 2, "Technical": 1},
    "Security Guard": {"Combat": 2, "Social": 1},
    "Nursing Assistant": {"Medical": 3, "Social": 1},
    "Mechanic": {"Technical": 3, "Scavenging": 1},
    "Cashier": {"Social": 2, "Scavenging": 1},
    "Cook": {"Technical": 1, "Social": 1, "Medical": 1},
    "Landscaper": {"Survival": 2, "Technical": 1},
    "Teacher": {"Social": 3},
    "Construction Worker": {"Technical": 3, "Combat": 1},
    "Office Worker": {"Social": 1, "Scavenging": 1},
    "Delivery Driver": {"Survival": 2, "Scavenging": 1},
    "College Student": {"Social": 1},
    "Bartender": {"Social": 3, "Combat": 1},
    "Retiree": {},
    "EMT": {"Medical": 4, "Survival": 1},
    "Hobbyist Hunter": {"Combat": 2, "Survival": 3},
}

const TRAITS := [
    "Calm", "Nervous", "Optimistic", "Pessimistic", "Generous", "Selfish",
    "Patient", "Impatient", "Brave", "Cautious", "Hotheaded", "Diplomatic",
    "Stubborn", "Observant", "Suspicious", "Friendly", "Loner", "Hard Worker",
    "Lazy", "Protective"
]

const INCOMPATIBLE_TRAITS := {
    "Calm": ["Nervous"],
    "Nervous": ["Calm"],
    "Optimistic": ["Pessimistic"],
    "Pessimistic": ["Optimistic"],
    "Generous": ["Selfish"],
    "Selfish": ["Generous"],
    "Patient": ["Impatient"],
    "Impatient": ["Patient"],
    "Brave": ["Cautious"],
    "Cautious": ["Brave"],
    "Friendly": ["Loner"],
    "Loner": ["Friendly"],
    "Hard Worker": ["Lazy"],
    "Lazy": ["Hard Worker"],
}

const FIRST_NAMES := [
    "Rachel", "Kyle", "Susan", "Marcus", "Erin", "David", "Luis", "Maya",
    "Lauren", "Daniel", "Jenna", "Sarah", "Devon", "Naomi", "Grant", "Elena",
    "Heather", "Jordan", "Sam", "Tara", "Chris", "Avery", "Morgan", "Drew",
    "Riley", "Casey", "Alex", "Nina", "Owen", "Priya", "Mateo", "Leah"
]

const LAST_NAMES := [
    "Morgan", "Reed", "Hale", "Walker", "Price", "Moreno", "Hill", "Cruz",
    "Park", "Klein", "Grant", "Torres", "Bennett", "Brooks", "Santos", "Nguyen",
    "Patel", "Miller", "Davis", "Foster", "Chen", "King", "Bishop", "Cole"
]

const ZONES := {
    "Camp Perimeter": {
        "duration": 10.0, "danger": "Minimal", "fatigue": 4, "loot_rolls": 1,
        "pressure": 10, "event_chance": 0.02,
        "loot": {
            "Dirty Water": 30, "Raw Food": 24,
            "Wood": 12, "Plastic": 9, "Cloth": 8, "Scrap Metal": 7, "Hardware": 4,
            "Clean Water": 5, "Cooked Food": 2
        }
    },
    "Nearby Streets": {
        "duration": 15.0, "danger": "Low", "fatigue": 6, "loot_rolls": 1,
        "pressure": 8, "event_chance": 0.08,
        "loot": {
            "Dirty Water": 28, "Raw Food": 22,
            "Wood": 11, "Plastic": 9, "Cloth": 8, "Scrap Metal": 8, "Hardware": 6,
            "Clean Water": 5, "Cooked Food": 2, "Seeds": 2, "Medicine": 1
        }
    },
    "Residential Blocks": {
        "duration": 25.0, "danger": "Moderate", "fatigue": 10, "loot_rolls": 1,
        "pressure": 6, "event_chance": 0.18,
        "loot": {
            "Dirty Water": 25, "Raw Food": 20,
            "Cloth": 10, "Wood": 9, "Plastic": 9, "Hardware": 8, "Scrap Metal": 7,
            "Clean Water": 5, "Cooked Food": 2, "Medicine": 4, "Seeds": 3, "Ammo": 2
        }
    },
    "Commercial Fringe": {
        "duration": 40.0, "danger": "High", "fatigue": 16, "loot_rolls": 1,
        "pressure": 5, "event_chance": 0.28,
        "loot": {
            "Dirty Water": 22, "Raw Food": 18,
            "Hardware": 12, "Scrap Metal": 11, "Plastic": 10, "Cloth": 9, "Wood": 7,
            "Clean Water": 5, "Cooked Food": 2, "Medicine": 5, "Ammo": 4, "Seeds": 3
        }
    },
    "Industrial Edge": {
        "duration": 60.0, "danger": "Severe", "fatigue": 22, "loot_rolls": 1,
        "pressure": 4, "event_chance": 0.35,
        "loot": {
            "Dirty Water": 20, "Raw Food": 16,
            "Scrap Metal": 14, "Hardware": 12, "Plastic": 10, "Wood": 8, "Cloth": 7,
            "Clean Water": 5, "Cooked Food": 2, "Ammo": 5, "Medicine": 3, "Seeds": 2
        }
    }
}

const ZONE_ORDER := [
    "Camp Perimeter", "Nearby Streets", "Residential Blocks", "Commercial Fringe", "Industrial Edge"
]

const ZONE_SUCCESS_TO_UNLOCK := {
    "Camp Perimeter": 2,
    "Nearby Streets": 3,
    "Residential Blocks": 3,
    "Commercial Fringe": 3,
}

const GEAR := {
    "Utility Knife": {"slot": "Weapon", "combat": 1, "size": 2},
    "Kitchen Knife": {"slot": "Weapon", "combat": 1, "size": 2},
    "Wooden Club": {"slot": "Weapon", "combat": 2, "size": 3},
    "Baseball Bat": {"slot": "Weapon", "combat": 2, "size": 3},
    "Hammer": {"slot": "Weapon", "combat": 2, "size": 2, "tool": "Hammer"},
    "Improvised Spear": {"slot": "Weapon", "combat": 2, "size": 3},
    "Crowbar": {"slot": "Weapon", "combat": 2, "size": 3, "tool": "Breach"},
    "Hatchet": {"slot": "Weapon", "combat": 3, "size": 2},
    "Pistol": {"slot": "Weapon", "combat": 4, "size": 2, "ammo": 1},
    "Shotgun": {"slot": "Weapon", "combat": 5, "size": 3, "ammo": 2},
    "Flashlight": {"slot": "Tool", "size": 2, "tool": "Light"},
    "Screwdriver Set": {"slot": "Tool", "size": 2, "technical": 1},
    "Bolt Cutters": {"slot": "Tool", "size": 3, "tool": "Cutters"},
    "Toolbox": {"slot": "Tool", "size": 3, "technical": 1},
    "First Aid Kit": {"slot": "Tool", "size": 2, "medical": 1},
    "Pry Tool": {"slot": "Tool", "size": 2, "tool": "Breach"},
    "Work Gloves": {"slot": "Clothing", "size": 1},
    "Heavy Boots": {"slot": "Clothing", "size": 2},
    "Leather Jacket": {"slot": "Clothing", "size": 2, "protect": 0.10},
    "Work Jacket": {"slot": "Clothing", "size": 2, "protect": 0.05},
    "Padded Jacket": {"slot": "Clothing", "size": 2, "protect": 0.05},
    "Worn Backpack": {"slot": "Pack", "capacity": 6, "size": 0},
    "School Backpack": {"slot": "Pack", "capacity": 8, "size": 0},
    "Improvised Pack": {"slot": "Pack", "capacity": 8, "size": 0},
    "Hiking Pack": {"slot": "Pack", "capacity": 12, "size": 0},
    "Reinforced Pack": {"slot": "Pack", "capacity": 12, "size": 0},
}

const RECIPES := {
    "Fire Pit": [
        {"id": "Cook Food", "time": 3.0, "cost": {"Raw Food": 1}, "gives_resource": {"Cooked Food": 2}},
        {"id": "Boil Water", "time": 3.0, "cost": {"Dirty Water": 1}, "gives_resource": {"Clean Water": 2}},
        {"id": "Sterile Dressing", "time": 5.0, "cost": {"Cloth": 1, "Clean Water": 1}, "gives_component": {"Sterile Dressing": 1}},
    ],
    "Workbench": [
        {"id": "Wooden Club", "time": 6.0, "cost": {"Wood": 2}, "gives_gear": "Wooden Club"},
        {"id": "Improvised Spear", "time": 8.0, "cost": {"Wood": 2, "Scrap Metal": 1}, "gives_gear": "Improvised Spear"},
        {"id": "Pry Tool", "time": 8.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Pry Tool"},
        {"id": "Hammer", "time": 8.0, "cost": {"Wood": 1, "Scrap Metal": 1}, "gives_gear": "Hammer"},
        {"id": "Framing Kit", "time": 8.0, "cost": {"Wood": 2, "Hardware": 1}, "gives_component": {"Framing Kit": 1}},
        {"id": "Pack Frame", "time": 8.0, "cost": {"Wood": 1, "Hardware": 1}, "gives_component": {"Pack Frame": 1}},
    ],
    "Sewing Table": [
        {"id": "Improvised Pack", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_gear": "Improvised Pack"},
        {"id": "Padded Jacket", "time": 10.0, "cost": {"Cloth": 3, "Plastic": 1}, "gives_gear": "Padded Jacket"},
        {"id": "Weatherproofing Roll", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_component": {"Weatherproofing Roll": 1}},
        {"id": "Reinforced Pack", "time": 12.0, "cost": {"Cloth": 2, "Plastic": 1}, "component_cost": {"Pack Frame": 1}, "gives_gear": "Reinforced Pack"},
    ]
}

const BUILDINGS := {
    "Rain Catcher": {"time": 10.0, "cost": {"Wood": 2, "Cloth": 1, "Plastic": 1}},
    "Makeshift Shelter": {"time": 15.0, "cost": {"Wood": 4, "Cloth": 2, "Plastic": 1}},
    "Storage Crate": {"time": 8.0, "cost": {"Wood": 2, "Hardware": 1}},
    "Workbench": {"time": 20.0, "cost": {"Wood": 4, "Scrap Metal": 2, "Hardware": 1}},
    "Sewing Table": {"time": 18.0, "cost": {"Wood": 3, "Cloth": 2, "Hardware": 1}, "requires": ["Workbench"]},
    "Garden Plot": {"time": 20.0, "cost": {"Wood": 3, "Seeds": 1}, "requires": ["Workbench"]},
    "Noise Line": {"time": 10.0, "cost": {"Scrap Metal": 1, "Hardware": 1, "Cloth": 1}},
    "Cabin": {
        "time": 45.0,
        "cost": {"Wood": 4, "Scrap Metal": 2},
        "component_cost": {"Framing Kit": 4, "Weatherproofing Roll": 2},
        "requires": ["Workbench", "Sewing Table"]
    }
}

const BUILD_ORDER := [
    "Rain Catcher", "Makeshift Shelter", "Storage Crate", "Workbench",
    "Sewing Table", "Garden Plot", "Noise Line", "Cabin"
]

const LEADER_ABILITIES := {
    "Organizer": "Crafting and building are 10% faster.",
    "Provider": "Routine scavenging sometimes yields one extra resource.",
    "Mediator": "Relationship damage from camp disputes is reduced.",
    "Caretaker": "Rest and medical recovery are improved.",
    "Watchful": "Camp surprise events are less dangerous.",
    "Pragmatist": "The first shortage penalty each day is reduced.",
}

const SPECIAL_SITES := {
    "Miller Street Market": {"zone": "Commercial Fringe", "duration": 30.0},
    "Neighborhood Clinic": {"zone": "Commercial Fringe", "duration": 30.0},
    "Hardware Cage": {"zone": "Commercial Fringe", "duration": 30.0},
    "Construction Trailer": {"zone": "Industrial Edge", "duration": 40.0},
    "Locked Industrial Office": {"zone": "Industrial Edge", "duration": 40.0},
}
