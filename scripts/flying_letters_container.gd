extends Node2D

## Manages the staggered appearance of all child FlyingLetter nodes.
##
## When this node transitions from invisible to visible, it hides all child
## CanvasItems and then reveals them one by one over _SPAWN_DURATION seconds,
## creating a "letters flowing in from the walls" effect.

const _SPAWN_DURATION: float = 1.0

var _pending: Array[Node] = []
var _spawn_interval: float = 0.0
var _next_spawn_time: float = 0.0
var _elapsed: float = 0.0
var _active: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_start_spawn()


func _start_spawn() -> void:
	_pending = get_children()
	# Hide every child so they can be revealed one at a time.
	for child: Node in _pending:
		if child is CanvasItem:
			(child as CanvasItem).visible = false
	_elapsed = 0.0
	_next_spawn_time = 0.0
	var count: int = _pending.size()
	_spawn_interval = _SPAWN_DURATION / float(max(count - 1, 1))
	_active = true


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	while not _pending.is_empty() and _elapsed >= _next_spawn_time:
		var child: Node = _pending.pop_front()
		if child is CanvasItem:
			(child as CanvasItem).visible = true
		_next_spawn_time += _spawn_interval
	if _pending.is_empty():
		_active = false
