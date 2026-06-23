# Git Worktrees Resources

## Knowledge

- [Official git-worktree documentation (git-scm.com)](https://git-scm.com/docs/git-worktree)
  The canonical reference. Use for: command syntax, flags, edge cases, and understanding the mental model.

- [Claude Code: Run parallel sessions with worktrees](https://code.claude.com/docs/en/worktrees)
  Official Claude Code docs on --worktree flag, EnterWorktree tool, subagent isolation, .worktreeinclude, cleanup, and baseRef settings. Use for: anything Claude Code-specific.

- [Git Worktrees for Parallel AI Agent Execution (Augment Code)](https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution)
  Practical guide on using worktrees with AI agents. Use for: workflow patterns, naming conventions, cleanup strategies.

- [Parallel Development without the Headaches (barrd.dev)](https://barrd.dev/article/parallel-development-without-the-headaches-using-git-worktree/)
  Clear walkthrough of worktree fundamentals with best practices. Use for: mental model building, the "rebase before PR" pattern.

- [Claude Code Worktree Parallel Guide (QCode.cc)](https://qcode.cc/claude-code-worktree-parallel-guide)
  Multi-agent workflow patterns with Claude Code worktrees. Use for: dev + review agent pattern, practical orchestration.

## Wisdom (Communities)

- [r/git](https://reddit.com/r/git)
  General git community. Use for: worktree edge cases, unusual setups, troubleshooting.

- [Claude Code GitHub Issues](https://github.com/anthropics/claude-code/issues)
  Use for: bugs and feature requests related to Claude Code's worktree support.

## Gaps

- No authoritative guide specifically on "dev agent + review agent" worktree patterns -- this is emerging practice, not documented canon. We'll synthesize from the sources above.
