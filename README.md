# teach-me

Personalized learning modules generated through AI-assisted teaching sessions. Each folder is a self-contained topic with missions, glossaries, resources, and interactive explainers.

## Topics

### [teach-me-git-worktree](./teach-me-git-worktree/)
Designing multi-agent workflows with Claude Code using git worktrees -- one agent develops, another reviews, both work concurrently on the same repo without conflicts.

### [teach-me-ralph-loops](./teach-me-ralph-loops/)
Preparing a 10-minute live presentation on Ralph loops for QE colleagues. Demonstrates turning manual test plan descriptions into runnable bash scripts using autonomous AI loops.

### [teach-me-sandcastle](./teach-me-sandcastle/)
Understanding Sandcastle's architecture for orchestrating AI coding agents in isolated Podman sandboxes -- branch strategies, worktree lifecycle, and AFK agent workflows.

### [teach-me-soldering](./teach-me-soldering/)
Practical soldering for ESP32 projects -- flux paste usage, clean joint technique, troubleshooting cold/bridged/dry joints, and apartment-safe workspace setup.

## Structure

Each topic follows the same layout:

```
teach-me-<topic>/
  MISSION.md          # Goal, success criteria, constraints
  GLOSSARY.md         # Key terms and definitions
  RESOURCES.md        # Curated links and references
  learning-records/   # Prior knowledge assessments, session notes
  *.html              # Interactive explainer pages (open in browser)
```
