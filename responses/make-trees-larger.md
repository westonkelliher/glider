# Making Trees Larger

Trees are generated in `_make_tree` (`environment/world.gd:45`). Every dimension — trunk height/radius, foliage height/radius — is multiplied by `scale` on **line 47**.

## Option A — quick (one line)

Bump the random range on line 47:

```gdscript
var scale := rng.randf_range(1.6, 3.2)   # was (0.8, 1.6) — doubles tree size
```

## Option B — live inspector knob (recommended)

Add an exported multiplier near the other `@export`s (~line 10):

```gdscript
@export var tree_scale: float = 1.0:
	set(v): tree_scale = v; _regenerate()
```

Then change line 47 to:

```gdscript
var scale := rng.randf_range(0.8, 1.6) * tree_scale
```

Gives you a **Tree Scale** slider that regenerates the forest live in-editor.
