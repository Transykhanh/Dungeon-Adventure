extends CharacterBody2D

@export var move_speed: float = 65.0
@export var aggro_range: float = 120.0
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.2

@onready var anim: AnimatedSprite2D = $Container/AnimatedSprite2D

var player: Node2D
var facing := "down"
var attacking := false
var dead := false
var attack_timer := 0.0


func _ready() -> void:
	add_to_group("enemies")
	anim.sprite_frames = _load_sprite_frames()
	anim.animation_finished.connect(_on_animation_finished)
	_play("idle")


func _physics_process(delta: float) -> void:
	if dead:
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		if not attacking:
			_play("idle")
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > aggro_range:
		velocity = Vector2.ZERO
		if not attacking:
			_play("idle")
		move_and_slide()
		return

	_update_facing(to_player)
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if not attacking and attack_timer <= 0.0:
			_start_attack()
		elif not attacking:
			_play("idle")
	else:
		velocity = to_player.normalized() * move_speed
		if not attacking:
			_play("walk")

	move_and_slide()


func take_damage() -> void:
	if dead:
		return
	dead = true
	attacking = false
	velocity = Vector2.ZERO
	_play("death")


func _start_attack() -> void:
	attacking = true
	attack_timer = attack_cooldown
	_play("attack")
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range:
		player.call("take_damage")


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "down" if direction.y > 0.0 else "up"


func _play(state: String) -> void:
	var animation_name := StringName(state + "_" + facing)
	if anim.sprite_frames.has_animation(animation_name) and anim.animation != animation_name:
		anim.play(animation_name)


func _on_animation_finished() -> void:
	var finished_animation := String(anim.animation)
	if finished_animation.begins_with("attack_"):
		attacking = false
	elif finished_animation.begins_with("death_"):
		queue_free()


func _load_sprite_frames() -> SpriteFrames:
	var sheet := load("res://Godot/goblin/goblin-sheet.png") as Texture2D
	var json_text := FileAccess.get_file_as_string("res://Godot/goblin/goblin-sheet.json")
	var metadata: Dictionary = JSON.parse_string(json_text)
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	for tag in metadata["meta"]["frameTags"]:
		var animation_name: String = tag["name"]
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, 10.0)
		var state := animation_name.get_slice("_", 0)
		sprite_frames.set_animation_loop(animation_name, state == "idle" or state == "walk")
		for frame_index in range(int(tag["from"]), int(tag["to"]) + 1):
			var frame_data: Dictionary = metadata["frames"][frame_index]
			var region: Dictionary = frame_data["frame"]
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = sheet
			atlas_frame.region = Rect2(region["x"], region["y"], region["w"], region["h"])
			var duration := float(frame_data["duration"]) / 100.0
			sprite_frames.add_frame(animation_name, atlas_frame, duration)

	return sprite_frames
