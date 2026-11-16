extends CharacterBody2D

## Top-down movement for the dungeon floor.
@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0
@export var acceleration: float = 1000.0
@export var jump_duration: float = 0.45
@export var jump_height: float = 18.0
@export var max_health: int = 5

@onready var anim: AnimatedSprite2D = $Container/AnimatedSprite2D
@onready var character_visual: Node2D = $Container

var is_attacking := false
var jump_time_left := 0.0
var visual_base_y := 0.0
var health: int
var hurt_time_left := 0.0
var is_dead := false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	# Keep the attack usable even in projects where the action was not added
	# through Project Settings yet. J and left mouse button both attack.
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var attack_key := InputEventKey.new()
		attack_key.physical_keycode = KEY_J
		InputMap.action_add_event("attack", attack_key)
		var attack_mouse := InputEventMouseButton.new()
		attack_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", attack_mouse)

	anim.animation_finished.connect(_on_animation_finished)
	visual_base_y = character_visual.position.y
	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	hurt_time_left = maxf(0.0, hurt_time_left - delta)

	var horizontal := float(Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D))
	horizontal -= float(Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A))
	var vertical := float(Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S))
	vertical -= float(Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W))
	var direction := Vector2(horizontal, vertical).normalized()
	var moving := not direction.is_zero_approx()
	var running := moving and Input.is_key_pressed(KEY_SHIFT)
	var target_speed := run_speed if running else walk_speed

	if moving:
		velocity = velocity.move_toward(direction * target_speed, acceleration * delta)
		_update_facing(direction)
	else:
		# Stop on the exact frame input is released, without sliding on the floor.
		velocity = Vector2.ZERO

	if Input.is_action_just_pressed("ui_accept") and jump_time_left <= 0.0:
		jump_time_left = jump_duration

	if jump_time_left > 0.0:
		jump_time_left = maxf(0.0, jump_time_left - delta)
		var jump_progress := 1.0 - jump_time_left / jump_duration
		character_visual.position.y = visual_base_y - sin(jump_progress * PI) * jump_height
		collision_layer = 4
		collision_mask = 1
	else:
		character_visual.position.y = visual_base_y
		collision_layer = 1
		collision_mask = 3

	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		anim.play("attack")
		_hit_nearby_enemies()
	elif not is_attacking:
		if hurt_time_left > 0.0:
			anim.play("hurt")
		elif jump_time_left > 0.0:
			anim.play("jump")
		elif moving:
			anim.play("run")
		else:
			anim.play("idle")

	move_and_slide()


func _on_animation_finished() -> void:
	if anim.animation == "attack":
		is_attacking = false
	elif anim.animation == "death":
		queue_free()


func take_damage(amount: int = 1) -> void:
	if is_dead or hurt_time_left > 0.0 or jump_time_left > 0.0:
		return
	health -= amount
	if health <= 0:
		is_dead = true
		is_attacking = false
		velocity = Vector2.ZERO
		anim.play("death")
	else:
		hurt_time_left = 0.5
		is_attacking = false
		anim.play("hurt")


func _hit_nearby_enemies() -> void:
	const ATTACK_RANGE := 42.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= ATTACK_RANGE:
			enemy.call("take_damage")


func _update_facing(direction: Vector2) -> void:
	# The supplied sheet has no separate up/down views. Keep it upright and
	# preserve the last horizontal facing while moving vertically.
	character_visual.rotation = 0.0
	if direction.x != 0.0:
		anim.flip_h = direction.x < 0.0
