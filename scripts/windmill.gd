extends AnimatableBody3D
## Obstáculo giratorio (aspas del molino o brazo barredor) sobre un eje local.

var speed := 1.3
var axis := Vector3(0, 0, 1)


func _physics_process(delta: float) -> void:
	rotate_object_local(axis, speed * delta)
