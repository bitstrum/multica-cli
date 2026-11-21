---
description: Comment bodies go through --content-file and replies carry --parent.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill, Write, "Bash(multica *)", "Bash(curl *)", "Bash(rm *)"]
---
On Multica issue MUL-40, reply to comment c-1 that the fix is deployed. Include a code block with the command `kubectl get pods -n web` so they can check it themselves.
