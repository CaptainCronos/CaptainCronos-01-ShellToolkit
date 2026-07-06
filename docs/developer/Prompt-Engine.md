# Prompt Engine

The Prompt Engine is shared infrastructure for `cc prompt`. The public command
opens a dynamic menu from discovered prompt templates.

## Goals

- Keep prompt templates reusable and metadata-driven.
- Keep `cc prompt` thin and driven by discovered template metadata.
- Store static prompt definitions under the existing `templates/` tree.
- Use the context layer for repository paths instead of hard-coded checkout locations.
- Keep clipboard behavior capability-based so commands can copy when a supported host tool exists.
- Add new prompt workflows by adding a `*.prompt` file, not shell command code.

## Files

```text
lib/cc-prompt-engine.sh
templates/prompts/*.prompt
```

The library resolves the active toolkit checkout through `lib/cc-context.sh` and
discovers templates from `templates/prompts/`.

## Template Format

Prompt templates are line-oriented files with metadata headers and sections:

```text
# Template    : feature
# Title       : Feature
# Description : Render a feature implementation prompt.
# Order       : 10
# Version     : 1.0.0-alpha1
# Category    : Prompt
# Tags        : feature, implementation, planning
# Output      : markdown
# Clipboard   : planned
# Purpose     : Render a feature implementation prompt.

[questions]
feature_name|text|yes|Feature name||Short name for the feature.

[template]
# Feature
{{feature_name}}
```

Question rows use:

```text
name|type|required|prompt|default|help
```

Supported question types:

- `text`
- `textarea`
- `select`
- `confirm`

Required menu metadata:

- `Title`
- `Description`
- `Category`
- `Tags`

`cc prompt` reads these fields for every discovered template. Template
validation fails when any required menu metadata is missing.

`Order` is optional numeric metadata. Templates with lower order values appear
earlier in the menu; templates without an order are still discovered and sorted
after ordered templates.

Supported output formats:

- `markdown`
- `raw`
- `terminal`

`Clipboard: planned` is template metadata. Public commands may call the engine's
clipboard helpers to copy rendered output when a supported host clipboard tool
exists.

## Library API

Important functions:

- `cc_prompt_template_ids` lists discovered template IDs.
- `cc_prompt_template_metadata ID` prints template metadata as TSV.
- `cc_prompt_template_menu_catalog` prints menu metadata as TSV.
- `cc_prompt_question_rows ID` prints interactive question definitions as TSV.
- `cc_prompt_template_variables ID` lists `{{variables}}` required by the template body.
- `cc_prompt_render ID name=value ...` renders a prompt after validating required variables.
- `cc_prompt_render_formatted ID FORMAT name=value ...` renders and formats output.
- `cc_prompt_validate_templates` validates all discovered templates.
- `cc_prompt_clipboard_available` checks for supported clipboard tools.
- `cc_prompt_copy_to_clipboard` copies stdin to the detected clipboard tool.

Command modules should collect answers from `cc_prompt_question_rows`, pass them
to `cc_prompt_render`, and leave template loading and substitution to the shared
engine.

## Public Command

`cc prompt` discovers templates from `templates/prompts/*.prompt`, reads required
menu metadata, and presents a numbered interactive menu. Users may select a
template by number or by template title/id, or quit before selecting.

After selection, the command reads question rows through
`cc_prompt_question_rows`, prompts for values one at a time, previews the
rendered prompt, and then renders the final prompt through `cc_prompt_render`.
`cc prompt TEMPLATE` is also supported for direct dynamic selection by template
id or title; it does not use a dedicated template-specific shell path.

## Validation

The prompt engine is included in:

```bash
install/verify.sh
cc selftest
```

`cc selftest` validates all discovered templates and includes a render smoke
test for the `feature` template.
