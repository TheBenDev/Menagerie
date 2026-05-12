---
title: Documentation workflow
page-type: guide
status: draft
---

Use this workflow whenever you add or update developer documentation in `! Menagerie Wiki/! Documentation`.

The structure is adapted from MDN Web Docs: landing pages provide orientation, guide pages teach tasks, and reference pages describe stable details.

## External references

- [MDN page types](https://developer.mozilla.org/en-US/docs/MDN/Writing_guidelines/Page_structures/Page_types)
- [MDN API reference guidance](https://developer.mozilla.org/en-US/docs/MDN/Writing_guidelines/Howto/Write_an_api_reference)
- [MDN writing style guide](https://developer.mozilla.org/en-US/docs/MDN/Writing_guidelines/Writing_style_guide)

## Page types

| Page type | Use it for | Required sections |
| --- | --- | --- |
| Navigation | Entry points and subsystem indexes. | Purpose, map of related pages, reading order, See also. |
| Guide | Task-focused docs. | Goal, prerequisites, steps, validation, related references, See also. |
| Reference | Details of a stable surface. | Summary, metadata, concepts and usage, API or fields, examples, See also. |
| Template | Reusable page skeletons. | Front matter, placeholder sections, completion checklist. |

## Inventory pass

Run this before writing or updating references:

```powershell
rg --files scripts data scenes -g '!*.uid' -g '!*.tmp' -g '!*.import'
rg "^(class_name|extends|signal|@export|func|static func|const)" scripts -g '*.gd' -n
rg "go_to_scene\(|scene_path_for\(|change_scene_to_file|start_combat|complete_combat" scripts -g '*.gd' -n
```

Treat `.uid`, `.tmp`, `.import`, `.godot`, and generated cache/build files as implementation noise unless you are documenting troubleshooting.

## Writing rules

- Start each page with a one-sentence purpose statement.
- Prefer short, concrete sections over long essays.
- Link to related pages using Obsidian links, such as `[[Combat flow]]`.
- Include source paths for code and resources, such as `res://core/combat/battle/battle_controller.gd`.
- Document public methods, signals, exported properties, resource schemas, route IDs, and stable IDs.
- Document private helpers only when they explain a non-obvious flow or abstraction.
- End every page with `## See also`.

## Update rules

Update docs in the same change as the code or resource change when any of these surfaces move:

- Autoload methods or signals.
- Scene route IDs accepted by `GameManager.go_to_scene()`.
- Exported resource fields.
- Signal payloads or connection responsibilities.
- Combat effect IDs, status IDs, audio IDs, or route music mappings.
- New scenes, scripts, resources, or asset groups.

## See also

- [[Start here]]
- [[Script reference template]]
- [[Resource reference template]]
- [[Guide page template]]
- [[Scene route reference template]]
- [[Signal reference template]]
