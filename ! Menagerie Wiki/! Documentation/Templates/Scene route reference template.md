---
title: Scene route reference template
page-type: template
status: draft
---

Use this template for a route or routed scene reference.

```markdown
---
title: Route name
page-type: reference
status: draft
---

One sentence explaining when this route is used.

## Metadata

| Item | Value |
| --- | --- |
| Route ref | `route_id` |
| Scene | `res://scenes/... .tscn` |
| Main script | `res://scenes/... .gd` |
| Music ID | `music.id` |

## Entry points

| Caller | Reason |
| --- | --- |

## Exit points

| Destination | Reason |
| --- | --- |

## Runtime state

Describe required autoload state, scene nodes, and resources.

## Validation

- Navigation works.
- Music mapping works.
- Scene loads headlessly.

## See also

- [[Start here]]
```

## See also

- [[Scene routes]]
- [[Adding a scene route]]
- [[Autoload APIs]]
