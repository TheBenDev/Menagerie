---
title: Script reference template
page-type: template
status: draft
---

Use this template for important script or class references.

````markdown
---
title: ClassOrScriptName
page-type: reference
status: draft
---

One sentence explaining what this script owns.

## Metadata

| Item | Value |
| --- | --- |
| Source | `res://core/...` or `res://scenes/...` |
| Class | `ClassName` or none |
| Extends | `Node`, `Resource`, etc. |
| Used by | Scenes, resources, or scripts |

## Concepts and usage

Explain when this script is used and what responsibilities it owns.

## Public API

| Method | Returns | Use |
| --- | --- | --- |
| `method_name()` | `void` | Meaning. |

## Exported properties

| Property | Type | Meaning |
| --- | --- | --- |

## Signals

| Signal | Payload | Meaning |
| --- | --- | --- |

## Data contracts

Describe dictionaries, arrays, resource schemas, or ID formats.

## Examples

```gdscript
Example.call()
```

## See also

- [[Start here]]
````

## See also

- [[Documentation workflow]]
- [[Key runtime APIs]]
- [[Script inventory]]
