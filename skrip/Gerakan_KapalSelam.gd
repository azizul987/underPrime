extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
const SPEED = 90.0
@onready var node_2d: Node2D = $".."
func _physics_process(delta: float) -> void:
	var directionx := Input.get_axis("ui_left", "ui_right")
	var directiony :=Input.get_axis("ui_up","ui_down")
	if(!((directionx==0&&directiony==0))||directionx&&directiony):
		print("kwkwkwk")
		if directionx && directiony==0:
			velocity.x = directionx * SPEED
			if directionx > 0:
				animated_sprite_2d.play("right")
			else :
				animated_sprite_2d.play("left")
				
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		if directiony && directionx==0:
			velocity.y=directiony*SPEED
			if directiony > 0:
				animated_sprite_2d.play("down")
			else :
				animated_sprite_2d.play("up")
		else:
			velocity.y = move_toward(velocity.y, 0, SPEED)
		move_and_slide()
	else:
		animated_sprite_2d.play("idle")
