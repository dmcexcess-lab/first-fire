extends RefCounted
class_name FFData

const RESOURCE_ORDER := [
    "Raw Food", "Cooked Food", "Dirty Water", "Clean Water", "Beer",
    "Wood", "Scrap Metal", "Cloth", "Plastic", "Hardware",
    "Zombie Corpse", "Seeds"
]

const STARTING_RESOURCES := {
    "Raw Food": 0,
    "Cooked Food": 3,
    "Dirty Water": 0,
    "Clean Water": 3,
    "Beer": 0,
    "Wood": 0,
    "Scrap Metal": 0,
    "Cloth": 0,
    "Plastic": 0,
    "Hardware": 0,
    "Zombie Corpse": 0,
    "Seeds": 0,
}

const COMPONENT_ORDER := [
    "Bandage", "First Aid Kit", "Zombie Cure",
    "Framing Kit", "Pack Frame", "Weatherproofing Roll"
]

const STARTING_COMPONENTS := {
    "Bandage": 0,
    "First Aid Kit": 0,
    "Zombie Cure": 0,
    "Framing Kit": 0,
    "Pack Frame": 0,
    "Weatherproofing Roll": 0,
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
        "duration": 37.5, "danger": "Minimal", "fatigue": 4, "loot_rolls": 1,
        "pressure": 10, "event_chance": 0.02,
        "loot": {
            "Dirty Water": 30, "Raw Food": 24,
            "Wood": 12, "Plastic": 9, "Cloth": 8, "Scrap Metal": 7, "Hardware": 4,
            "Clean Water": 5, "Cooked Food": 2
        }
    },
    "Nearby Streets": {
        "duration": 62.5, "danger": "Low", "fatigue": 6, "loot_rolls": 1,
        "pressure": 8, "event_chance": 0.08,
        "loot": {
            "Dirty Water": 28, "Raw Food": 22,
            "Wood": 11, "Plastic": 9, "Cloth": 8, "Scrap Metal": 8, "Hardware": 6,
            "Clean Water": 5, "Cooked Food": 2, "Seeds": 2, "First Aid Kit": 1
        }
    },
    "Residential Blocks": {
        "duration": 100.0, "danger": "Moderate", "fatigue": 10, "loot_rolls": 1,
        "pressure": 6, "event_chance": 0.18,
        "loot": {
            "Dirty Water": 25, "Raw Food": 20,
            "Cloth": 10, "Wood": 9, "Plastic": 9, "Hardware": 8, "Scrap Metal": 7,
            "Clean Water": 5, "Cooked Food": 2, "First Aid Kit": 3, "Zombie Cure": 1, "Seeds": 3
        }
    },
    "Commercial Fringe": {
        "duration": 150.0, "danger": "High", "fatigue": 16, "loot_rolls": 1,
        "pressure": 5, "event_chance": 0.28,
        "loot": {
            "Dirty Water": 22, "Raw Food": 18,
            "Hardware": 12, "Scrap Metal": 11, "Plastic": 10, "Cloth": 9, "Wood": 7,
            "Clean Water": 5, "Cooked Food": 2, "First Aid Kit": 4, "Zombie Cure": 1, "Seeds": 3
        }
    },
    "Industrial Edge": {
        "duration": 225.0, "danger": "Severe", "fatigue": 22, "loot_rolls": 1,
        "pressure": 4, "event_chance": 0.35,
        "loot": {
            "Dirty Water": 20, "Raw Food": 16,
            "Scrap Metal": 14, "Hardware": 12, "Plastic": 10, "Wood": 8, "Cloth": 7,
            "Clean Water": 5, "Cooked Food": 2, "First Aid Kit": 3, "Zombie Cure": 1, "Seeds": 2
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
    "Utility Knife": {"slot": "Weapon", "combat": 1},
    "Kitchen Knife": {"slot": "Weapon", "combat": 1},
    "Wooden Club": {"slot": "Weapon", "combat": 2},
    "Baseball Bat": {"slot": "Weapon", "combat": 2},
    "Hammer": {"slot": "Weapon", "combat": 2, "tool": "Hammer"},
    "Improvised Spear": {"slot": "Weapon", "combat": 2},
    "Crowbar": {"slot": "Weapon", "combat": 2, "tool": "Breach"},
    "Sledgehammer": {"slot": "Weapon", "combat": 4},
    "Hatchet": {"slot": "Weapon", "combat": 5},
    "Crossbow": {"slot": "Weapon", "combat": 3},
    "6-Shot Revolver": {"slot": "Weapon", "combat": 5},
    "12-Shot Automatic": {"slot": "Weapon", "combat": 5},
    "Double-Barrel Shotgun": {"slot": "Weapon", "combat": 5},
    "Pump Shotgun": {"slot": "Weapon", "combat": 5},
    "Medium Rifle": {"slot": "Weapon", "combat": 5},
    "Long Rifle": {"slot": "Weapon", "combat": 5},
    "Pistol": {"slot": "Weapon", "combat": 5, "legacy_alias": "6-Shot Revolver"},
    "Shotgun": {"slot": "Weapon", "combat": 5, "legacy_alias": "Double-Barrel Shotgun"},
    "Rifle": {"slot": "Weapon", "combat": 5, "legacy_alias": "Long Rifle"},
    "Flashlight": {"slot": "Secondary", "light": "cone", "light_range": 8.5, "light_spread": 0.52, "light_strength": 1.0, "light_color": "edf5d6", "view_bonus": 2, "charge_max": 100.0, "charge_per_tick": 0.025},
    "Lock Pick": {"slot": "Secondary", "uses_min": 1, "uses_max": 3},
    "Firecracker": {"slot": "Secondary", "uses": 1},
    "Headlamp": {"slot": "Secondary", "light": "cone", "light_range": 7.0, "light_spread": 0.34, "light_strength": 0.88, "light_color": "f1edc5", "view_bonus": 1, "legacy": true},
    "Lantern": {"slot": "Secondary", "light": "radial", "light_range": 4.5, "light_strength": 0.88, "light_color": "ffc46f", "view_bonus": 0, "legacy": true},
    "Glow Stick": {"slot": "Secondary", "light": "radial", "light_range": 3.0, "light_strength": 0.58, "light_color": "71ef68", "view_bonus": 0, "legacy": true},
    "Road Flare": {"slot": "Secondary", "light": "radial", "light_range": 4.8, "light_strength": 0.92, "light_color": "ff5b48", "view_bonus": 0, "legacy": true},
    "Screwdriver Set": {"slot": "Tool", "technical": 1},
    "Bolt Cutters": {"slot": "Tool", "tool": "Cutters"},
    "Toolbox": {"slot": "Tool", "technical": 1},
    "Pry Tool": {"slot": "Tool", "tool": "Breach"},
    "Work Gloves": {"slot": "Clothing"},
    "Heavy Boots": {"slot": "Clothing"},
    "Leather Jacket": {"slot": "Clothing", "protect": 0.10},
    "Work Jacket": {"slot": "Clothing", "protect": 0.05},
    "Padded Jacket": {"slot": "Clothing", "protect": 0.05},
    "Worn Backpack": {"slot": "Pack", "capacity": 6},
    "School Backpack": {"slot": "Pack", "capacity": 6},
    "Improvised Pack": {"slot": "Pack", "capacity": 6},
    "Hiking Pack": {"slot": "Pack", "capacity": 8},
    "Reinforced Pack": {"slot": "Pack", "capacity": 8},
}

const TACTICAL_GEAR_UNLOCKS_BY_ZONE := {
    "Camp Perimeter": [
        "Utility Knife", "Kitchen Knife", "Wooden Club", "Flashlight", "Firecracker",
        "Screwdriver Set", "Work Gloves", "Worn Backpack", "School Backpack", "Improvised Pack"
    ],
    "Nearby Streets": [
        "Baseball Bat", "Hammer", "Improvised Spear", "Lock Pick", "Pry Tool",
        "Work Jacket", "Heavy Boots"
    ],
    "Residential Blocks": [
        "Crowbar", "Crossbow", "Toolbox", "Padded Jacket", "Leather Jacket", "Hiking Pack"
    ],
    "Commercial Fringe": [
        "Bolt Cutters", "Reinforced Pack", "Sledgehammer", "Hatchet",
        "6-Shot Revolver", "Double-Barrel Shotgun"
    ],
    "Industrial Edge": [
        "12-Shot Automatic", "Pump Shotgun", "Medium Rifle", "Long Rifle"
    ],
}

const RECIPES := {
    "Fire Pit": [
        {"id": "Cook Food", "time": 3.0, "cost": {"Raw Food": 1}, "gives_resource": {"Cooked Food": 2}},
        {"id": "Boil Water", "time": 3.0, "cost": {"Dirty Water": 1}, "gives_resource": {"Clean Water": 2}},
        {"id": "Bandage", "time": 5.0, "cost": {"Cloth": 1, "Clean Water": 1}, "gives_component": {"Bandage": 1}},
        {"id": "Community Stew", "time": 8.0, "cost": {"Raw Food": 2}, "requires": ["Tavern"], "gives_resource": {"Cooked Food": 5}},
        {"id": "Kitchen Supper", "time": 10.0, "cost": {"Raw Food": 3, "Clean Water": 1}, "requires": ["Tavern Kitchen"], "gives_resource": {"Cooked Food": 8}},
        {"id": "Brew Beer", "time": 20.0, "cost": {"Raw Food": 2, "Clean Water": 2}, "requires": ["Tavern Brewery"], "gives_resource": {"Beer": 4}},
    ],
    "Workbench": [
        {"id": "Utility Knife", "time": 6.0, "cost": {"Scrap Metal": 1, "Cloth": 1}, "gives_gear": "Utility Knife"},
        {"id": "Kitchen Knife", "time": 6.0, "cost": {"Scrap Metal": 1, "Plastic": 1}, "gives_gear": "Kitchen Knife"},
        {"id": "Wooden Club", "time": 6.0, "cost": {"Wood": 2}, "gives_gear": "Wooden Club"},
        {"id": "Baseball Bat", "time": 8.0, "cost": {"Wood": 3}, "gives_gear": "Baseball Bat"},
        {"id": "Hammer", "time": 8.0, "cost": {"Wood": 1, "Scrap Metal": 1}, "gives_gear": "Hammer"},
        {"id": "Improvised Spear", "time": 8.0, "cost": {"Wood": 2, "Scrap Metal": 1}, "gives_gear": "Improvised Spear"},
        {"id": "Crowbar", "time": 9.0, "cost": {"Scrap Metal": 2, "Hardware": 1}, "gives_gear": "Crowbar"},
        {"id": "Crossbow", "time": 14.0, "cost": {"Wood": 3, "Scrap Metal": 1, "Hardware": 2, "Cloth": 1}, "requires": ["Armory"], "gives_gear": "Crossbow"},
        {"id": "Sledgehammer", "time": 15.0, "cost": {"Wood": 2, "Scrap Metal": 4, "Hardware": 3}, "requires": ["Armory"], "gives_gear": "Sledgehammer"},
        {"id": "Hatchet", "time": 18.0, "cost": {"Wood": 1, "Scrap Metal": 5, "Hardware": 4}, "requires": ["Armory"], "gives_gear": "Hatchet"},
        {"id": "Lock Pick", "time": 5.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Lock Pick"},
        {"id": "Screwdriver Set", "time": 7.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Screwdriver Set"},
        {"id": "Bolt Cutters", "time": 11.0, "cost": {"Scrap Metal": 3, "Hardware": 2}, "requires": ["Armory"], "gives_gear": "Bolt Cutters"},
        {"id": "Toolbox", "time": 12.0, "cost": {"Scrap Metal": 2, "Hardware": 3}, "requires": ["Armory"], "gives_gear": "Toolbox"},
        {"id": "Pry Tool", "time": 8.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Pry Tool"},
        {"id": "Framing Kit", "time": 8.0, "cost": {"Wood": 2, "Hardware": 1}, "gives_component": {"Framing Kit": 1}},
    ],
    "Sewing Table": [
        {"id": "Work Gloves", "time": 5.0, "cost": {"Cloth": 1}, "gives_gear": "Work Gloves"},
        {"id": "Heavy Boots", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1, "Scrap Metal": 1}, "gives_gear": "Heavy Boots"},
        {"id": "Leather Jacket", "time": 10.0, "cost": {"Cloth": 3, "Plastic": 1}, "gives_gear": "Leather Jacket"},
        {"id": "Work Jacket", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_gear": "Work Jacket"},
        {"id": "Padded Jacket", "time": 10.0, "cost": {"Cloth": 3, "Plastic": 1}, "gives_gear": "Padded Jacket"},
        {"id": "Weatherproofing Roll", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_component": {"Weatherproofing Roll": 1}},
    ],
    "Infirmary": [
        {"id": "Zombie Cure", "time": 20.0, "cost": {"Zombie Corpse": 2}, "gives_component": {"Zombie Cure": 1}},
    ]
}

const BUILDINGS := {
    "Large Tarp": {"time": 12.0, "cost": {"Wood": 2, "Cloth": 3, "Plastic": 1}, "description": "First shelter expansion. Raises the hard population cap to 7 and improves sleep quality and mood recovery."},
    "Rain Catcher": {"time": 10.0, "cost": {"Wood": 2, "Cloth": 1, "Plastic": 1}, "description": "Produces 1 Dirty Water each day. A Water Tank doubles the daily yield."},
    "Workbench": {"time": 12.0, "cost": {"Wood": 2, "Scrap Metal": 1}, "description": "Light first fabrication bench. Unlocks all non-hearth crafting paths and basic tools, weapons and structural components."},
    "Noise Line": {"time": 10.0, "cost": {"Scrap Metal": 1, "Hardware": 1, "Cloth": 1}, "description": "Early warning line that raises camp safety and lowers perimeter injury risk."},
    "Tavern": {"time": 28.0, "cost": {"Wood": 6, "Cloth": 2, "Plastic": 2, "Hardware": 2}, "requires": ["Large Tarp", "Workbench"], "description": "Stage 1 hearth upgrade: roof, cooking spit and rough benches. Unlocks Community Stew and improves social mood recovery."},
    "Tavern Kitchen": {"time": 38.0, "cost": {"Wood": 8, "Scrap Metal": 3, "Plastic": 2, "Hardware": 4}, "component_cost": {"Weatherproofing Roll": 1}, "requires": ["Tavern", "Sewing Table", "Garden Plot", "Water Tank"], "description": "Stage 2 tavern: proper tables, prep space and better cookware. Unlocks Kitchen Supper for stronger raw-to-cooked conversion and improves social recovery."},
    "Tavern Brewery": {"time": 52.0, "cost": {"Wood": 10, "Scrap Metal": 6, "Plastic": 4, "Hardware": 5}, "component_cost": {"Weatherproofing Roll": 1}, "requires": ["Tavern Kitchen", "Barracks", "Water Tank", "Garden Plot"], "description": "Stage 3 tavern: brewing vessels, bar and mature gathering hall. Unlocks Beer and the strongest tavern social recovery."},
    "Sewing Table": {"time": 18.0, "cost": {"Wood": 3, "Cloth": 2, "Hardware": 1}, "requires": ["Large Tarp", "Workbench"], "description": "Unlocks clothing and weatherproofing crafting."},
    "Garden Plot": {"time": 20.0, "cost": {"Wood": 3, "Seeds": 1}, "requires": ["Workbench"], "description": "Produces 2 Raw Food on days it is tended."},
    "Water Tank": {"time": 24.0, "cost": {"Scrap Metal": 5, "Plastic": 4, "Hardware": 2}, "requires": ["Rain Catcher", "Workbench"], "description": "Doubles the daily Rain Catcher output and provides a visible camp water reserve."},
    "Barracks": {"time": 46.0, "cost": {"Wood": 10, "Cloth": 5, "Plastic": 3, "Hardware": 2}, "component_cost": {"Framing Kit": 3, "Weatherproofing Roll": 2}, "requires": ["Large Tarp", "Workbench", "Sewing Table"], "description": "Permanent twelve-person sleeping quarters. Strongly improves sleep recovery, mood recovery, and camp safety."},
    "Infirmary": {"time": 38.0, "cost": {"Wood": 8, "Cloth": 4, "Plastic": 5, "Hardware": 4}, "component_cost": {"Bandage": 2}, "requires": ["Barracks", "Workbench", "Water Tank"], "description": "Late medical infrastructure. Speeds treatment and wound recovery, reduces untreated critical decline, and crafts Zombie Cure from recovered corpses."},
    "Watch Post": {"time": 32.0, "cost": {"Wood": 6, "Scrap Metal": 3, "Hardware": 3}, "requires": ["Noise Line", "Workbench"], "description": "Strong perimeter overwatch that further raises safety and reduces outside-event danger."},
    "Armory": {"time": 46.0, "cost": {"Wood": 10, "Scrap Metal": 10, "Hardware": 8, "Plastic": 3}, "requires": ["Barracks", "Workbench", "Watch Post"], "description": "Late secure fabrication area. Requires established housing and perimeter tech, then unlocks advanced Workbench weapons and tools."},
    "Dormitory": {"time": 62.0, "cost": {"Wood": 16, "Scrap Metal": 8, "Cloth": 6, "Hardware": 6}, "component_cost": {"Framing Kit": 5, "Weatherproofing Roll": 3}, "requires": ["Barracks", "Tavern Kitchen", "Infirmary", "Sewing Table", "Water Tank"], "description": "Final eighteen-person housing tier. Requires a mature support network and provides the camp's best sleep and mood recovery."},
}

const BUILD_ORDER := [
    "Large Tarp", "Rain Catcher", "Workbench", "Noise Line", "Tavern",
    "Sewing Table", "Garden Plot", "Water Tank", "Tavern Kitchen", "Barracks",
    "Infirmary", "Watch Post", "Tavern Brewery", "Armory", "Dormitory"
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
    "Miller Street Market": {"zone": "Commercial Fringe", "duration": 150.0},
    "Neighborhood Clinic": {"zone": "Commercial Fringe", "duration": 150.0},
    "Hardware Cage": {"zone": "Commercial Fringe", "duration": 150.0},
    "Construction Trailer": {"zone": "Industrial Edge", "duration": 225.0},
    "Locked Industrial Office": {"zone": "Industrial Edge", "duration": 225.0},
}
