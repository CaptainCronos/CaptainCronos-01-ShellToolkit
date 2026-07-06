# Prompt Engine

The Prompt Engine is shared infrastructure for `cc prompt` and future
interactive command flows. The public command discovers templates and handles
terminal input, while `lib/cc-prompt-engine.sh` owns template discovery,
metadata parsing, session state, answer validation, rendering, and output hooks.

## Architecture

```text
tools/commands/prompt
  |
  v
lib/cc-prompt-engine.sh
  |-- template discovery
  |-- metadata catalog
  |-- question definitions
  |-- session state
  |-- validation rules
  |-- render hooks
  |-- clipboard helpers
  v
templates/prompts/*.prompt
```

The engine resolves the active toolkit checkout through `lib/cc-context.sh` and
discovers templates from `templates/prompts/`. Adding a prompt workflow should
normally require only a new `*.prompt` file.

## Template Authoring Guide

Prompt templates are line-oriented files with metadata headers and sections:

```text
# Template    : feature
# Title       : Feature
# Description : Render a feature implementation prompt.
# Order       : 10
# Version     : 1.0.0-alpha1
# Category    : Prompt
# Author      : Captain Cronos Project
# Tags        : feature, implementation, planning
# Validation  : question-rules
# Default     : question defaults
# Examples    : feature_name, repository_context, objective
# Output      : markdown
# Clipboard   : planned

[questions]
name|type|required|prompt|default|help|validation|examples

[validation]
name|rule|argument|message

[template]
# Feature
{{name}}
```

Question rows support `text`, `textarea`, `select`, and `confirm`. The required
field is `yes` or `no`. The `validation` and `examples` columns are optional,
so existing six-column rows remain valid.

## Metadata Reference

Required metadata:

- `Title`: human-readable menu label.
- `Description`: short menu/help description.
- `Version`: template contract version.
- `Category`: menu grouping.
- `Author`: template owner.
- `Tags`: comma-separated search and menu tags.

Optional metadata:

- `Template` or `Id`: stable template id; defaults to the filename stem.
- `Order`: numeric menu sort order.
- `Validation`: template-level validation mode or note.
- `Default`: template-level default policy or note.
- `Examples`: template-level example summary.
- `Output` or `Format`: default output format.
- `Clipboard`: clipboard behavior note.
- `Purpose`: internal inventory description.

Metadata keys are matched case-insensitively.

## Session Lifecycle

Interactive flows start a session with:

```bash
cc_prompt_session_start TEMPLATE_ID
```

The session tracks the current template, current question index, cancellation
state, question definitions, defaults, validation specs, examples, and entered
answers. Answers are stored in session arrays and are preserved while moving
with `cc_prompt_session_next`, `cc_prompt_session_previous`, or
`cc_prompt_session_back`. `cc_prompt_session_cancel` marks the flow cancelled.

Rendering a completed session uses:

```bash
cc_prompt_session_render
cc_prompt_session_render_formatted markdown
```

The public `cc prompt` command wraps this lifecycle with numbered menus,
breadcrumbs, progress indicators, contextual help, and graceful Ctrl+C handling.

## Validation Framework

Required and optional checks come from the question row. Additional checks may
be declared inline in the `validation` column with semicolon-separated rules:

```text
name|text|yes|Name|||regex=^[A-Za-z0-9 ._-]+$|Prompt Engine
audience|select|yes|Audience|||enum=user,developer,admin|developer
retries|text|no|Retries|3||range=0..10|3
path|text|yes|Config path|||path=file|./config.yml
```

The `[validation]` section can attach a message to a rule:

```text
[validation]
name|regex|^[A-Za-z0-9 ._-]+$|Use letters, numbers, spaces, dots, dashes, or underscores.
mode|enum|plan,apply,dry-run|Choose plan, apply, or dry-run.
count|range|1..25|Choose a number from 1 through 25.
config|path|file|Provide an existing file path.
hook|validator|my_validator|Custom validator rejected the answer.
```

Supported validation rules:

- `required` and `optional`
- `regex`
- `enum` or `choices`
- `range`, `numeric`, or `number`
- `path`, `exists`, `file`, or `dir`
- `validator` or `custom`

Custom validators are shell functions available at validation time. The hook is
called as:

```bash
validator_function TEMPLATE_ID QUESTION_NAME ANSWER
```

It must return zero for a valid answer and nonzero for an invalid answer.

## Rendering Hooks

`cc_prompt_format_output FORMAT TEMPLATE_ID` routes rendered content through a
named output hook. Supported formats are:

- `markdown`: pass-through Markdown output.
- `raw`: pass-through raw output.
- `terminal`: terminal header plus rendered content.
- `clipboard`: copy rendered content to a supported clipboard tool.
- `json`: JSON-shaped output reserved for future automation.

Clipboard helpers remain capability-based and detect `wl-copy`, `xclip`,
`xsel`, `pbcopy`, or `clip.exe`.

## Public Command

`cc prompt` discovers templates, shows a numbered menu, and accepts selection by
number, id, or exact title. `cc prompt TEMPLATE` skips the menu and starts the
selected template directly.

During question entry, users may enter:

- `previous` or `back`
- `next`
- `help`
- `cancel`

After preview, the numbered actions are Generate, Edit, and Cancel.

## Validation

The prompt engine is included in:

```bash
install/verify.sh
cc selftest
```

`cc selftest` validates all discovered templates and includes a render smoke
test for the `feature` template.
