# Prompt Engine

The Prompt Engine is internal infrastructure for future `cc prompt` commands.
It does not expose a user-facing command yet.

## Goals

- Keep prompt templates reusable and metadata-driven.
- Keep future `cc prompt feature`, `cc prompt bugfix`, `cc prompt docs`, and related commands thin.
- Store static prompt definitions under the existing `templates/` tree.
- Use the context layer for repository paths instead of hard-coded checkout locations.
- Reserve clipboard behavior for a future command layer without implementing copy support now.

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
# Version     : 1.0.0-alpha1
# Category    : Prompt
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

Supported output formats:

- `markdown`
- `raw`
- `terminal`

`Clipboard: planned` is metadata only. The engine does not copy to the system
clipboard.

## Library API

Important functions:

- `cc_prompt_template_ids` lists discovered template IDs.
- `cc_prompt_template_metadata ID` prints template metadata as TSV.
- `cc_prompt_question_rows ID` prints interactive question definitions as TSV.
- `cc_prompt_template_variables ID` lists `{{variables}}` required by the template body.
- `cc_prompt_render ID name=value ...` renders a prompt after validating required variables.
- `cc_prompt_render_formatted ID FORMAT name=value ...` renders and formats output.
- `cc_prompt_validate_templates` validates all discovered templates.

Future command modules should collect answers from `cc_prompt_question_rows`,
pass them to `cc_prompt_render`, and leave template loading and substitution to
the shared engine.

## Validation

The prompt engine is included in:

```bash
install/verify.sh
cc selftest
```

`cc selftest` includes a render smoke test for the `feature` template.
