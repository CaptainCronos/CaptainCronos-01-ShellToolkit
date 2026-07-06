# Templates

Repository-managed templates live under this directory.

## Prompt Templates

Prompt templates live in:

```text
templates/prompts/
```

They are consumed by the internal prompt engine:

```text
lib/cc-prompt-engine.sh
```

Each `*.prompt` file uses metadata headers plus two sections:

```text
# Title       : Feature
# Description : Render a feature implementation prompt.
# Order       : 10
# Version     : 1.0.0-alpha1
# Category    : Prompt
# Author      : Captain Cronos Project
# Tags        : feature, implementation, planning
# Validation  : question-rules
# Default     : question defaults
# Examples    : feature_name, objective
# Output      : markdown

[questions]
name|type|required|prompt|default|help|validation|examples

[validation]
name|rule|argument|message

[template]
Prompt body with {{variables}}.
```

Supported question types are `text`, `textarea`, `select`, and `confirm`.
The required flag is `yes` or `no`. Validation supports required/optional
fields, regex rules, enumerated choices, numeric ranges, path existence checks,
and custom validator hooks.

`Title`, `Description`, `Version`, `Category`, `Author`, and `Tags` are
required menu metadata. `Order` is optional and controls menu placement when
present.
Prompt commands render these templates through the shared engine rather than
parsing template files themselves. `cc prompt` discovers every `*.prompt` file
in this directory automatically.
