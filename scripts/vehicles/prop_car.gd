class_name PropCar
extends AnimatableBody3D
## A non-player car: parked, or driven by traffic AI along a lane. Cheap to run.
## The player can take it over at any time with make_drivable().

var model_name := ""
var spec := {}
var visual: Node3D
var wheel_meshes: Array[Node3D] = []
var speed := 0.0


static func create(name: String) -> PropCar:
	var c := PropCar.new()
	c.model_name = name
	return c


func _ready() -> void:
	add_to_group("cars")
	collision_layer = 4
	collision_mask = 0
	sync_to_physics = false
	spec = CarLook.spec(model_name)
	visual = CarLook.instantiate(model_name)
	add_child(visual)
	visual.rotation.y = PI
	for n in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
		var w := visual.find_child(n, true, false) as Node3D
		if w:
			wheel_meshes.append(w)
	var L: float = spec.get("length", 4.6)
	var W: float = spec.get("width", 1.8)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(W * 0.96, 1.25, L * 0.97)
	cs.shape = b
	cs.position.y = 0.75
	add_child(cs)


func _process(delta: float) -> void:
	if speed > 0.1 and wheel_meshes.size() > 0:
		for w in wheel_meshes:
			# Spin each wheel about its own hub (vertices are baked in car space).
			var hub := (w as MeshInstance3D).get_aabb().get_center() if w is MeshInstance3D else Vector3.ZERO
			var ang := -speed * delta / float(spec.get("wheel_r", 0.33))
			var t := Transform3D(Basis(Vector3.BACK, ang), Vector3.ZERO)
			w.transform = w.transform * Transform3D(Basis(), hub) * t * Transform3D(Basis(), -hub)


## Swaps this prop for a physics car at the same spot and returns it.
func make_drivable() -> Car:
	var car := Car.create(model_name)
	var xf := global_transform
	get_parent().add_child(car)
	car.global_transform = Transform3D(xf.basis, xf.origin + Vector3(0, 0.05, 0))
	car.linear_velocity = xf.basis.z * speed
	queue_free()
	return car
