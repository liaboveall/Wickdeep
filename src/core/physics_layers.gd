class_name PhysicsLayers
extends RefCounted
## Collision layer bits. Walls are the only thing bodies collide with; actors hit each other by
## distance checks, which keeps hundreds of bullets cheap.

const WORLD := 1
const PLAYER := 2
const ENEMY := 4
