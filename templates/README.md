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
[questions]
name|type|required|prompt|default|help

[template]
Prompt body with {{variables}}.
```

Supported question types are `text`, `textarea`, `select`, and `confirm`.
The required flag is `yes` or `no`.

The prompt engine is internal infrastructure only. Future `cc prompt ...`
commands should render these templates through the shared engine rather than
parsing template files themselves.
