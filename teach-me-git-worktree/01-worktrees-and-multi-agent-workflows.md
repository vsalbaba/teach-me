# Git Worktrees for Multi-Agent Workflows

*How worktrees enable a dev agent and a review agent to work on the same repo simultaneously*

---

**Contents**
1. [The Problem: One Repo, Multiple Agents](#1-the-problem-one-repo-multiple-agents)
2. [What a Worktree Actually Is](#2-what-a-worktree-actually-is)
3. [Worktrees in Claude Code](#3-worktrees-in-claude-code)
4. [The Dev + Review Agent Pattern](#4-the-dev--review-agent-pattern)
5. [Constraints and Gotchas](#5-constraints-and-gotchas)
6. [Check Your Understanding](#6-check-your-understanding)

---

## 1. The Problem: One Repo, Multiple Agents

You want two Claude Code agents running at the same time on the same repository -- one writing code, one reviewing and refactoring. Without isolation, they'd trample each other's files. Every edit by one agent would corrupt the working directory for the other.

You could clone the repo twice, but that duplicates the entire `.git` history on disk and the two copies don't share refs -- fetching in one doesn't update the other. [[1]](#sources)

> **Key insight:** Git worktrees solve this by giving you multiple working directories that share a single `.git` directory. Same history, same remotes, same refs -- different checkouts.

## 2. What a Worktree Actually Is

Every git repo has a **main worktree** -- the directory you cloned into. With `git worktree add`, you create **linked worktrees**: additional working directories, each checked out to a different branch, all pointing back to the same `.git` data. [[1]](#sources)

```
my-project/                  <-- main worktree (branch: main)
  .git/                      <-- shared repository data
  src/
  ...

.claude/worktrees/
  feature-auth/              <-- linked worktree (branch: worktree-feature-auth)
    src/
    ...
  review-refactor/           <-- linked worktree (branch: worktree-review-refactor)
    src/
    ...
```

### What's shared, what's not

- **Shared** (one copy): commit history, remote tracking, refs, tags, config
- **Separate per worktree**: working files, index (staging area), HEAD, checked-out branch

This means a commit made in one worktree is immediately visible from any other worktree (it's in the shared object store). But the files on disk in each worktree are independent -- editing `src/auth.ts` in one worktree doesn't touch it in another. [[1]](#sources)

### The one-branch rule

A branch can only be checked out in **one worktree at a time**. If `main` is checked out in your main worktree, a linked worktree must use a different branch. This prevents two worktrees from racing to update the same branch ref. [[1]](#sources)

> **Try this:** In any git repo, run these commands to see worktrees in action:
>
> ```bash
> # Create a linked worktree on a new branch
> git worktree add ../my-repo-experiment -b experiment
>
> # See both worktrees listed
> git worktree list
>
> # The new worktree has the full repo, on its own branch
> cd ../my-repo-experiment && git branch
>
> # Clean up when done
> cd - && git worktree remove ../my-repo-experiment
> ```

## 3. Worktrees in Claude Code

Claude Code has built-in worktree support via two mechanisms: [[2]](#sources)

### The `--worktree` CLI flag

Start a Claude Code session in an isolated worktree:

```bash
# Terminal 1: dev agent
claude --worktree dev-feature

# Terminal 2: review agent
claude --worktree review-feature
```

This creates `.claude/worktrees/dev-feature/` on branch `worktree-dev-feature`, and similarly for the review worktree. Each session is fully isolated. [[2]](#sources)

### The `EnterWorktree` tool (mid-session)

You can also ask Claude to "work in a worktree" during a running session. Claude calls the `EnterWorktree` tool internally, creating a worktree and switching the session into it. [[2]](#sources)

### Subagent isolation

When dispatching subagents (via the Agent tool), you can set `isolation: "worktree"` so each subagent gets its own worktree automatically. This is the key building block for multi-agent workflows: [[2]](#sources)

```js
// In a workflow script or when spawning agents:
agent("Implement the auth module", { isolation: "worktree" })
agent("Review and refactor the auth module", { isolation: "worktree" })
```

### Base branch control

By default, worktrees branch from `origin/HEAD` (clean remote state). Set `worktree.baseRef` to `"head"` in settings to branch from your current local HEAD instead -- useful when a review agent needs to see in-progress work: [[2]](#sources)

```json
// .claude/settings.json
{
  "worktree": {
    "baseRef": "head"
  }
}
```

### Cleanup

- **No changes made**: worktree and branch are removed automatically on exit
- **Changes exist**: Claude prompts you to keep or remove
- **Subagent worktrees**: auto-removed if unchanged, otherwise kept until `cleanupPeriodDays` expires [[2]](#sources)

> **Try this:** Start two Claude Code sessions in worktrees right now:
>
> ```bash
> # In your project directory:
>
> # Terminal 1
> claude --worktree dev-session
>
> # Terminal 2
> claude --worktree review-session
>
> # Back in the main checkout, see them both:
> git worktree list
> ```

## 4. The Dev + Review Agent Pattern

Here's how your workflow maps onto worktrees:

```
                    ┌─────────────────────┐
                    │   Your main repo    │
                    │   (branch: main)    │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                                 │
   ┌──────────▼──────────┐          ┌───────────▼──────────┐
   │   Dev Agent          │          │   Review Agent        │
   │   worktree: dev      │          │   worktree: review    │
   │   branch: worktree-  │          │   branch: worktree-   │
   │          dev         │          │          review       │
   │                      │          │                       │
   │   Writes new code    │  commit  │   Reads dev's commits │
   │   Runs tests         │ ──────>  │   Reviews & refactors │
   │   Commits            │          │   Commits fixes       │
   └──────────────────────┘          └───────────────────────┘
              │                                 │
              └────────────────┬────────────────┘
                               │
                          merge both
                          into main
```

### Step by step

1. **Dev agent** starts in its worktree, writes code, commits to its branch
2. **Review agent** starts in a separate worktree. To see the dev agent's work, it either:
   - Checks out the dev agent's branch (after the dev agent is done with it), or
   - Cherry-picks / merges the dev agent's commits into its own branch
3. **Review agent** refactors, commits improvements to its own branch
4. **You** merge both branches into main (or the review agent's branch supersedes the dev's)

> **Key insight:** The critical sequencing decision: can the review agent start *before* the dev agent commits? Yes -- but it can only review commits, not uncommitted working-tree changes in the other worktree. If you want true parallel work, the dev agent should commit frequently so the review agent can pull those commits.

### The simpler sequential pattern

For many cases, a sequential pattern is cleaner:

1. Dev agent works in worktree A, commits, pushes branch
2. Review agent starts in worktree B, checks out the dev's branch, reviews and refactors
3. Review agent commits its changes on top, opens a PR

This avoids merge complexity. The review agent builds directly on the dev agent's work.

## 5. Constraints and Gotchas

> **Watch out:**
>
> - **One branch per worktree**: Two worktrees can't have the same branch checked out simultaneously. Plan your branch names.
> - **Port conflicts**: If both agents try to run dev servers, they'll fight over the same port. Use different ports per worktree.
> - **Database state**: Both worktrees share any local database. If one agent runs a migration, the other's schema is now different.
> - **.env files aren't copied**: Use `.worktreeinclude` to auto-copy gitignored files into new worktrees. [[2]](#sources)
> - **Lock files**: `git worktree lock` prevents cleanup while an agent is running. Don't manually delete worktree directories -- use `git worktree remove`.
> - **Subagent cost**: Worktree isolation adds ~200-500ms setup per agent. Don't use it when agents aren't editing files.

## 6. Check Your Understanding

**Q1: What does a linked worktree share with the main worktree?**

<details>
<summary>Show answer</summary>

**Commit history, refs, remotes, and config.** Working files and the staging area are separate per worktree. A linked worktree is not a symlink (they have independent file trees) and not a full clone (they share the `.git` object store).

</details>

---

**Q2: Can two worktrees have the same branch checked out?**

<details>
<summary>Show answer</summary>

**No -- each branch can only be checked out in one worktree at a time.** This prevents two worktrees from racing to update the same branch ref.

</details>

---

**Q3: How can a review agent see uncommitted changes from a dev agent's worktree?**

<details>
<summary>Show answer</summary>

**It can't -- only committed changes are visible through the shared object store.** Uncommitted working-tree changes are private to each worktree. This is why the dev agent should commit frequently if you want the review agent to see progress in real time.

</details>

---

**Q4: What does `worktree.baseRef: "head"` do in Claude Code settings?**

<details>
<summary>Show answer</summary>

**Makes worktrees branch from your current local HEAD, carrying unpushed commits.** The default is `"fresh"`, which branches from `origin/HEAD` (clean remote state). Use `"head"` when a review agent needs to see in-progress local work.

</details>

---

### Sources

1. [git-worktree Documentation (git-scm.com)](https://git-scm.com/docs/git-worktree)
2. [Claude Code: Run parallel sessions with worktrees](https://code.claude.com/docs/en/worktrees)
3. [Parallel Development without the Headaches (barrd.dev)](https://barrd.dev/article/parallel-development-without-the-headaches-using-git-worktree/)
