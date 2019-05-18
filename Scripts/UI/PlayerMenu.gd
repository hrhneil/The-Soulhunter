extends Control

onready var main_stats = $Container/SheetContainer/CharacterSheet/Stats
onready var tabs = $Container/Tabs
onready var buttons = $Container/Buttons

onready var detailed_stats = $Container/Tabs/Stats/Grid

onready var inventory = $Container/Tabs/Inventory/Slots
onready var inventory_description = $Container/Tabs/Inventory/Description

onready var equipment = $Container/Tabs/Equipment/Equipment
onready var equipment_inventory = $Container/Tabs/Equipment/Inventory
onready var equipment_description = $Container/Tabs/Equipment/Description

enum TABS{STATS, INVENTORY, EQUIPMENT, SOULS}

var current_tab
var tab_buttons = ButtonGroup.new()

var stacks = {}

var inventory_select = 0
var equipment_select = 0
var equipment_inventory_select = -1

var newest_stats = {}

func _ready():
	visible = false
	Com.controls.connect("key_press", self, "on_key_press")
	Network.connect("stats", self, "update_stats")
	Network.connect("inventory", self, "update_inventory")
	Network.connect("equipment", self, "update_equipment")
	
	for button in buttons.get_children():
		button.set_button_group(tab_buttons)
	
	for slot in inventory.get_children():
		slot.clear_item()
	select_inventory()
	
	for slot in equipment.get_children():
		slot.clear_item()
	for slot in equipment_inventory.get_children():
		slot.clear_item()
	select_equipment()
	
	change_tab(TABS.STATS)

var level = 1

func update_stats(stats):
	if "level" in stats:
		level = stats.level
	
	if "exp" in stats:
		detailed_stats.get_node("EXPValue").text = str(stats.exp)
		detailed_stats.get_node("NEXTValue").text = str(Com.exp_for_level(level) - stats.exp + Com.total_exp_for_level(level-1))
	
	if "attack" in stats:
		set_main_stat("ATKValue", stats.attack)
	
	if "defense" in stats:
		set_main_stat("DEFValue", stats.defense)
	
	if "magic_attack" in stats:
		set_main_stat("MATKValue", stats.magic_attack)
	
	if "magic_defense" in stats:
		set_main_stat("MDEFValue", stats.magic_defense)
	
	if "luck" in stats:
		set_main_stat("LCKValue", stats.luck)
	
	for stat in stats:
		newest_stats[stat] = stats[stat]

func update_inventory(items):
	stacks = {}
	
	for i in items.size():
		var item = items[i]
		
		if item in stacks:
			stacks[item].amount += 1
		else:
			stacks[item] = {item = Res.get_res(Res.items, item).name, amount = 1, origin = i}
	
	for i in inventory.get_child_count():
		if i < stacks.size():
			inventory.get_child(i).set_item(stacks[stacks.keys()[i]])
		else:
			inventory.get_child(i).clear_item()
	
	select_inventory()
	update_equipment_inventory()

func update_equipment(items):
	for i in 8:
		if items[i] > 0:
			equipment.get_child(i).set_item(Res.get_res(Res.items, items[i]).name)
		else:
			equipment.get_child(i).clear_item()
	
	select_equipment()

func update_equipment_inventory():
	var available = []
	var filter = get_filter()
	
	for stack in stacks.values():
		if Res.items[stack.item].type in filter:
			available.append(stack)
	
	for i in equipment_inventory.get_child_count():
		if i < available.size():
			equipment_inventory.get_child(i).set_item(available[i])
		else:
			equipment_inventory.get_child(i).clear_item()
	
	select_equipment_inventory()

func set_main_stat(stat, value, compare = false):
	var node = main_stats.get_node(stat)
	var old_value = int(node.text)
	node.text = str(value)
	
	if compare:
		if old_value > value:
			node.modulate = Color.hotpink
		elif old_value < value:
			node.modulate = Color.cyan
		else:
			node.modulate = Color.white

func on_key_press(p_id, key, state):
	if state == Controls.State.ACTION:
		if key == Controls.MENU:
			activate()
	elif state == Controls.State.MENU:
		if key == Controls.MENU:
			deactivate()
		
		if key == Controls.SWAP:
			change_tab((current_tab+1) % TABS.size())
		
		if current_tab == TABS.INVENTORY:
			var old_select = inventory_select
			if key == Controls.RIGHT:
				inventory_select = min(inventory_select + 1, inventory.get_child_count()-1)
			elif key == Controls.LEFT:
				inventory_select = max(inventory_select - 1, 0)
			elif key == Controls.DOWN:
				inventory_select = min(inventory_select + inventory.columns, inventory.get_child_count()-1)
			elif key == Controls.UP:
				inventory_select = max(inventory_select - inventory.columns, 0)
			
			if inventory_select != old_select:
				select_inventory()
		
		elif current_tab == TABS.EQUIPMENT:
			if equipment_inventory_select == -1:
				var old_select = equipment_select
				if key == Controls.RIGHT:
					equipment_select = min(equipment_select + 1, equipment.get_child_count()-1)
				elif key == Controls.LEFT:
					equipment_select = max(equipment_select - 1, 0)
				elif key == Controls.DOWN:
					equipment_select = min(equipment_select + inventory.columns, equipment.get_child_count()-1)
				elif key == Controls.UP:
					equipment_select = max(equipment_select - inventory.columns, 0)
				
				if key == Controls.ACCEPT:
					equipment_inventory_select = 0
					select_equipment()
				
				if equipment_select != old_select:
					select_equipment()
			else:
				var old_select = equipment_inventory_select
				if key == Controls.RIGHT:
					equipment_inventory_select = min(equipment_inventory_select + 1, equipment_inventory.get_child_count()-1)
				elif key == Controls.LEFT:
					equipment_inventory_select = max(equipment_inventory_select - 1, 0)
				elif key == Controls.DOWN:
					equipment_inventory_select = min(equipment_inventory_select + inventory.columns, equipment_inventory.get_child_count()-1)
				elif key == Controls.UP:
					equipment_inventory_select = max(equipment_inventory_select - inventory.columns, 0)
				
				if key == Controls.ACCEPT:
					equip_item()
					preview_stats(null)
					
				if key == Controls.CANCEL:
					equipment_inventory_select = -1
					select_equipment()
					preview_stats(null)
				
				if equipment_inventory_select != old_select:
					select_equipment_inventory()

func equip_item():
	var selected = equipment_inventory.get_child(equipment_inventory_select)
	
	if !selected.empty():
		Packet.new(Packet.TYPE.EQUIP).add_u8(equipment_select).add_u8(selected.stack.origin).send()
		equipment_inventory_select = -1
		select_equipment()

func activate():
	Com.controls.state = Controls.State.MENU
	visible = true

func deactivate():
	Com.controls.state = Controls.State.ACTION
	visible = false

func change_tab(i):
	current_tab = i
	buttons.get_child(i).pressed = true
	
	for tab in tabs.get_child_count():
		tabs.get_child(tab).visible = (current_tab == tab)

func select_inventory():
	var selected = inventory.get_child(inventory_select)
	for slot in inventory.get_children():
		slot.select(selected)
	
	if selected.empty():
		inventory_description.visible = false
	else:
		inventory_description.visible = true
		
		var item = selected.stack_item
		inventory_description.get_node("Panel2/Text").text = Res.items[item].description
		inventory_description.get_node("Panel1/Icon").texture = Res.item_icon(item)

func select_equipment():
	var selected = equipment.get_child(equipment_select)
	for slot in equipment.get_children():
		slot.select(selected, equipment_inventory_select == -1)
	
	if selected.empty():
		equipment_description.visible = false
	else:
		equipment_description.visible = true
		
		var item = selected.item_name
		equipment_description.get_node("Panel2/Text").text = Res.items[item].description
		equipment_description.get_node("Panel1/Icon").texture = Res.item_icon(item)
	
	update_equipment_inventory()

func select_equipment_inventory():
	if equipment_inventory_select > -1:
		var selected = equipment_inventory.get_child(equipment_inventory_select)
		for slot in equipment_inventory.get_children():
			slot.select(selected)
		
		if selected.empty():
			equipment_description.visible = false
			preview_stats(null)
		else:
			equipment_description.visible = true
			var item = selected.stack_item
			equipment_description.get_node("Panel2/Text").text = Res.items[item].description
			equipment_description.get_node("Panel1/Icon").texture = Res.item_icon(item)
			preview_stats(item)
	else:
		for slot in equipment_inventory.get_children():
			slot.select(null)

const MAIN_STAT_LIST = ["attack", "defense", "magic_attack", "magic_defense", "luck"]
const STAT_LABELS = {attack = "ATKValue", defense = "DEFValue", magic_attack = "MATKValue", magic_defense = "MDEFValue", luck = "LCKValue"}

func preview_stats(item):
	if item:
		var data = Res.items[item]
		
		for stat in MAIN_STAT_LIST:
			if stat in data:
				set_main_stat(STAT_LABELS[stat], newest_stats[stat] + data[stat], true)
	else:
		for stat in MAIN_STAT_LIST:
			set_main_stat(STAT_LABELS[stat], newest_stats[stat])

func get_filter():
	match equipment_select:
		0:
			return ["weapon"]
		1:
			if false: #dual-wield
				return ["weapon", "shield"]
			else:
				return ["shield"]
		2:
			return ["armor"]
		3:
			return ["helmet"]
		4:
			return ["legs"]
		5:
			return ["boots"]
		6:
			return ["cape"]
		7, 8:
			return ["accessory"]