# Mission: Sandcastle with Podman

## Why
Understand how Sandcastle orchestrates AI coding agents inside isolated Podman sandboxes -- branch strategies, worktree lifecycle, prompt expansion, and iteration loops -- so you can set up AFK agent workflows for your own repos.

## Success looks like
- Can explain Sandcastle's architecture: host, sandbox, agent provider, branch strategy
- Understands bind-mount vs isolated sandbox providers and when to use each
- Can set up a Podman-based sandbox with `sandcastle init` and run an agent
- Knows how branch strategies (head, merge-to-head, branch) control where commits land
- Can design multi-step workflows using `createSandbox()` and `createWorktree()`

## Constraints
- Already familiar with Claude Code CLI
- Podman available on host (Fedora)
- Focus on practical setup and workflow design, not Sandcastle internals

## Out of scope
- Writing custom sandbox providers from scratch
- Vercel/cloud sandbox providers
- Building Sandcastle from source
