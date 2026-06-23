# Mission: Git Worktrees

## Why
Design a multi-agent workflow using Claude Code where one agent develops code in one worktree while another agent reviews and refactors in a separate worktree -- both operating on the same repository concurrently without stepping on each other.

## Success looks like
- Can explain what a worktree is, how it relates to branches, and when it's the right tool
- Can create, list, and remove worktrees confidently
- Can design a Claude Code workflow where a dev agent and a review agent work in parallel via separate worktrees
- Understands the constraints -- what you can and can't do across worktrees (shared refs, lock files, etc.)

## Constraints
- Already comfortable with git branches (create, switch, merge)
- Already uses Claude Code CLI
- Focus on practical workflow design, not git internals deep-dive

## Out of scope
- Git internals (object model, packfiles, ref storage format)
- Non-worktree parallelism strategies (multiple clones, stashing)
- CI/CD integration
