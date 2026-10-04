class_name DockLink
extends Object
## Folding a craft's body into its anchor, and taking it back apart.

const SHELL_GROUP := &"docked_shell"


static func split(shell: Ship, outward: Vector2, undock_impulse: float) -> void:
	var anchor := shell.docked_anchor

	# 1. shell back to the world first, still frozen.
	shell.process_mode = Node.PROCESS_MODE_INHERIT
	shell.reparent(shell.docked_home, true)

	# 2. pull the children back. Still keep_global_transform, so nothing visibly moves.
	for child in shell.docked_children:
		if is_instance_valid(child):
			child.reparent(shell, true)
	shell.docked_children.clear()

	# 3. mass after the shapes have left, same reason as merge step 3.
	if anchor is RigidBody2D:
		anchor.mass -= shell.docked_mass_contribution

	# 4. unfreeze BEFORE writing velocities - a frozen kinematic body discards them.
	shell.freeze = false
	if anchor is RigidBody2D:
		shell.linear_velocity = anchor.linear_velocity
		shell.angular_velocity = anchor.angular_velocity
	shell.apply_central_impulse(outward * undock_impulse)
	shell.remove_from_group(SHELL_GROUP)


static func merge(
		mover: Ship,
		anchor: PhysicsBody2D,
		mover_mount: MountPoint,
		anchor_mount: MountPoint,
		target: Transform2D,
) -> void:
	# 1. park the mover exactly on the dock pose and take it out of the sim.
	# Pose BEFORE transferring - every child reparents with keep_global_transform,
	# so getting the shell right is what places all of them correctly.
	mover.thrust_direction = Vector2.ZERO
	mover.spin_direction = 0.0
	mover.linear_velocity = Vector2.ZERO
	mover.angular_velocity = 0.0
	mover.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	mover.freeze = true
	mover.global_transform = target

	mover.docked_anchor = anchor
	mover.docked_home = mover.get_parent()
	mover.docked_mass_contribution = mover.mass
	mover.docked_children.clear()

	# 2. hand the functional children to the anchor BODY, flat.
	for child in mover.get_children():
		if child == mover.autopilot or child.is_in_group(&"stays_with_shell"):
			continue
		child.reparent(anchor, true)
		mover.docked_children.append(child)

	# 3. mass last, once the anchor owns the shapes. `inertia` stays 0 so the
	# server recomputes the tensor from the new shape set; assigning `mass` is
	# what kicks that recompute off.
	if anchor is RigidBody2D:
		anchor.mass += mover.docked_mass_contribution

	# 4. the now-empty shell rides the mount. No shapes, so it has no physical
	# presence; it exists to remember what it owns.
	mover.reparent(anchor_mount, true)
	mover.add_to_group(SHELL_GROUP)
	mover.process_mode = Node.PROCESS_MODE_DISABLED

	anchor_mount.docked_to = mover_mount
	mover_mount.docked_to = anchor_mount
	anchor_mount.docked_shell = mover # how _live_autopilot() finds it again
	anchor_mount.set_dock_sensing(false)
	mover_mount.set_dock_sensing(false)
