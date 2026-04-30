---
title: Resource reference template
page-type: template
status: draft
---

Use this template for `.tres` resource schemas or important authored resources.

````markdown
---
title: ResourceName
page-type: reference
status: draft
---

One sentence explaining what this resource configures.

## Metadata

| Item | Value |
| --- | --- |
| Resource path | `res://data/...` |
| Script class | `ClassName` |
| Runtime consumers | Scripts or scenes |

## Concepts and usage

Explain how this resource enters runtime.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |

## Examples

```gdscript
var resource := load("res://data/...")
```

## Authoring notes

- Godot/editor practices.
- Subresource ordering rules.
- UID/reference expectations.

## See also

- [[Start here]]
````

## See also

- [[Documentation workflow]]
- [[Resource inventory]]
- [[Data and resource model]]
