extends CharacterBody2D

@export var move_speed: float = 55.0
@export var aggro_range: float = 120.0
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.0

@onready var anim: AnimatedSprite2D = $Container/AnimatedSprite2D
@onready var visual: Node2D = $Container

var target: CharacterBody2D
var attacking := false
var dead := false
var attack_timer := 0.0


func _ready() -> void:
	add_to_group("enemies")
	anim.animation_finished.connect(_on_animation_finished)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	if dead:
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		_play_if_changed("idle")
		return

	var to_player := target.global_position - global_position
	var distance := to_player.length()
	if distance <= aggro_range:
		if to_player.x != 0.0:
			anim.flip_h = to_player.x < 0.0

		if distance <= attack_range:
			velocity = Vector2.ZERO
			if not attacking and attack_timer <= 0.0:
				_start_attack()
			elif not attacking:
				_play_if_changed("idle")
		else:
			velocity = to_player.normalized() * move_speed
			if not attacking:
				_play_if_changed("move")
	else:
		velocity = Vector2.ZERO
		if not attacking:
			_play_if_changed("idle")

	move_and_slide()


func take_damage() -> void:
	if dead:
		return
	dead = true
	attacking = false
	velocity = Vector2.ZERO
	anim.play("death")


func _start_attack() -> void:
	attacking = true
	attack_timer = attack_cooldown
	anim.play("attack")
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range:
		target.call("take_damage")


func _on_animation_finished() -> void:
	if anim.animation == "attack":
		attacking = false
	elif anim.animation == "death":
		queue_free()


func _play_if_changed(animation_name: StringName) -> void:
	if anim.animation != animation_name:
		anim.play(animation_name)
