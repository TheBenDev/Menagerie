---
title: Signal reference template
page-type: template
status: draft
---

Use this template for documenting a signal or event contract.

```markdown
---
title: Emitter.signal_name
page-type: reference
status: draft
---

One sentence explaining when this signal is emitted.

## Metadata

| Item | Value |
| --- | --- |
| Emitter | `ClassName` |
| Source | `res://core/...` or `res://scenes/...` |
| Signal | `signal_name(...)` |

## Payload

| Parameter | Type | Meaning |
| --- | --- | --- |

## Emitted when

- Condition or method that emits it.

## Consumers

| Consumer | Effect |
| --- | --- |

## Notes

- Ordering guarantees.
- Nullability.
- Reentrancy or async concerns.

## See also

- [[Start here]]
```

## See also

- [[Signals and events]]
- [[Documentation workflow]]
