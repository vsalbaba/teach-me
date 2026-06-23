# Ralph Loops Glossary

Terminology for the presentation on autonomous Claude Code loops.

## Terms

**Ralph loop**:
A bash loop that runs Claude headless, checks a mechanical completion condition, and repeats until the condition passes or a budget is exhausted. State persists through the filesystem; context resets each iteration.
_Avoid_: agent loop, autonomous loop (too generic)

**Completion promise**:
A predefined marker string (e.g., `RALPH_COMPLETE`) that the agent emits when it believes the task is done. The harness greps for it to break the loop -- the agent doesn't decide when to stop, the harness does.
_Avoid_: done signal, exit marker

**Headless mode** (`-p`):
Claude Code flag that reads a prompt, executes, writes output, then exits. No interactive session. Required for Ralph loops.
_Avoid_: pipe mode, batch mode

**Prompt template**:
A markdown file containing the task instructions, completion criteria, and constraints that gets fed to each Ralph iteration. The loop script injects dynamic context (e.g., git log, file lists) alongside it.
_Avoid_: system prompt, instructions file
