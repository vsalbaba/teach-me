# Lesson 1: Sandcastle + Podman Architecture

*How Sandcastle sandboxes Claude Code in Podman, and what you need for your pipeline analysis harness.*

**Contents**
1. [The Mental Model](#1-the-mental-model)
2. [Bind-Mount Architecture](#2-bind-mount-architecture)
3. [The Podman Provider Internals](#3-the-podman-provider-internals)
4. [Vertex AI Auth in the Sandbox](#4-vertex-ai-auth-in-the-sandbox)
5. [Mapping Your Harness to Sandcastle](#5-mapping-your-harness-to-sandcastle)
6. [What Goes in the Containerfile](#6-what-goes-in-the-containerfile)
7. [What's Next](#7-whats-next)

## 1. The Mental Model

Sandcastle does three things:

1. **Spins up a container** with your repo bind-mounted in
2. **Runs Claude Code inside it** with `--dangerously-skip-permissions`
3. **Manages git** -- worktrees, branches, commits, merging back

The container is the blast radius boundary. Claude Code has full autonomy *inside* the container (it can run any command, edit any file), but it cannot affect the host beyond the bind-mounted directories.

```
  HOST (your machine)
  ┌─────────────────────────────────────────────────────┐
  │                                                     │
  │  your-project/     # bind-mounted into container    │
  │  ├── discover.py                                    │
  │  ├── .claude/agents/                                │
  │  ├── tmp/          # downloaded logs                │
  │  └── insights/     # analysis output                │
  │                                                     │
  │  ~/.config/gcloud/  # ADC credentials (mounted ro)  │
  │                                                     │
  └────────────┬───────────────────────────┬────────────┘
               │ bind-mount                │ bind-mount (ro)
  ┌────────────▼───────────────────────────▼────────────┐
  │  PODMAN CONTAINER                                   │
  │                                                     │
  │  /home/agent/workspace/  <- your project            │
  │  /home/agent/.config/gcloud/  <- ADC creds          │
  │                                                     │
  │  claude --print --dangerously-skip-permissions      │
  │    └── runs discover.py                             │
  │    └── analyzes logs                                │
  │    └── searches JIRA                                │
  │    └── writes insights/                             │
  │                                                     │
  │  Installed: python3, java, pyyaml, git, claude CLI  │
  └─────────────────────────────────────────────────────┘
```

*Source: [mattpocock/sandcastle README](https://github.com/mattpocock/sandcastle) -- "Bind-mount providers: the worktree directory is bind-mounted into the container, so the agent writes directly to the host filesystem through the mount."*

## 2. Bind-Mount Architecture

Sandcastle has two types of sandbox providers. Podman is a **bind-mount provider**:

| Type | How files flow | Providers |
|---|---|---|
| **Bind-mount** | Host directory mounted directly into container. Agent writes through the mount -- changes appear on host immediately. | Docker, Podman |
| **Isolated** | Sandbox has its own filesystem. Files must be explicitly synced in/out via `copyIn`/`copyFileOut`. | Vercel |

This means your `insights/` directory appears on the host as soon as Claude writes it inside the container. No copy step needed.

> **SELinux Note (Red Hat):** Since you're on Fedora/RHEL, SELinux is active. Sandcastle defaults `selinuxLabel: "z"` on all bind mounts, which adds the `:z` suffix to volume flags. This applies a shared SELinux label so the container can read/write the mounted directory. This is the right default for your setup.

*Source: [podman.ts:42-48](https://github.com/mattpocock/sandcastle/blob/main/src/sandboxes/podman.ts#L42-L48) -- selinuxLabel defaults to "z", described as "No-op on non-SELinux systems."*

## 3. The Podman Provider Internals

Here's exactly what happens when Sandcastle creates a Podman sandbox:

### Step 1: Pre-flight checks

- On macOS/Windows: verifies Podman Machine is running (skipped on Linux -- you're fine)
- Runs `podman image inspect <imageName>` to verify image exists

### Step 2: Container start

```bash
podman run -d
  --name sandcastle-<uuid>
  --user 1000:1000
  --userns=keep-id:uid=1000,gid=1000   # rootless UID mapping
  -w /home/agent/workspace              # working directory
  -e HOME=/home/agent                    # env vars
  -e CLAUDE_CODE_USE_VERTEX=1
  -e CLOUD_ML_REGION=global
  -e ANTHROPIC_VERTEX_PROJECT_ID=...
  -v /path/to/worktree:/home/agent/workspace:z  # project
  -v ~/.config/gcloud:/home/agent/.config/gcloud:ro,z  # ADC
  --entrypoint sleep
  sandcastle:your-project
  infinity
```

The container just runs `sleep infinity`. All actual work happens via `podman exec`.

### Step 3: Agent execution

Sandcastle calls `podman exec` to run Claude Code inside the warm container:

```bash
podman exec -i sandcastle-<uuid> sh -c \
  'claude --print --verbose --dangerously-skip-permissions \
   --output-format stream-json \
   --model claude-opus-4-8 -p -'
```

The prompt is piped via stdin (`-p -`). Output is streamed back line-by-line as JSON events.

### Step 4: Cleanup

`podman rm -f sandcastle-<uuid>` -- registered as a shutdown hook so containers are cleaned up even on SIGINT/crash.

*Source: [podman.ts:222-254](https://github.com/mattpocock/sandcastle/blob/main/src/sandboxes/podman.ts#L222-L254) (container start), [AgentProvider.ts:1190-1215](https://github.com/mattpocock/sandcastle/blob/main/src/AgentProvider.ts#L1190-L1215) (Claude Code command builder)*

### The `--userns=keep-id` mechanism

This is the key to rootless Podman. It maps your host UID to UID 1000 inside the container, so:

- Files created inside the container are owned by *your* user on the host
- Bind-mounted files are readable without permission issues
- No root access needed on the host

## 4. Vertex AI Auth in the Sandbox

Claude Code on Vertex uses **Application Default Credentials (ADC)**. The auth chain inside the container needs to find your credentials. Three things must be true:

| What | How |
|---|---|
| Env vars set | `CLAUDE_CODE_USE_VERTEX=1`, `CLOUD_ML_REGION=global`, `ANTHROPIC_VERTEX_PROJECT_ID=<id>` |
| ADC file accessible | Mount `~/.config/gcloud/application_default_credentials.json` (read-only) into the container at the same relative path under `/home/agent/` |
| `GOOGLE_APPLICATION_CREDENTIALS` or default path | The ADC library checks `$HOME/.config/gcloud/application_default_credentials.json` by default. Since `HOME=/home/agent`, the mount path `/home/agent/.config/gcloud/` is found automatically. |

> **Try this:** Verify your ADC credentials exist on the host:
>
> ```bash
> cat ~/.config/gcloud/application_default_credentials.json | \
>   python3 -c "import json,sys; d=json.load(sys.stdin); \
>   print(f'Type: {d[\"type\"]}, Project: {d.get(\"quota_project_id\",\"N/A\")}')"
> ```
>
> If this fails, run `gcloud auth application-default login` first.

*Source: [Claude Code on Vertex AI docs](https://code.claude.com/docs/en/google-vertex-ai) -- "Set CLAUDE_CODE_USE_VERTEX=1, CLOUD_ML_REGION, ANTHROPIC_VERTEX_PROJECT_ID."*

## 5. Mapping Your Harness to Sandcastle

Your current flow is interactive -- you talk to Claude Code agents in the IDE. With Sandcastle, there are two options:

### Option A: `run()` with a single comprehensive prompt

Write a TypeScript orchestration script. Give Claude Code one prompt that includes the full analysis instructions (pulled from your agent definitions). Claude does everything in one shot inside the container.

```typescript
import { run } from "@ai-hero/sandcastle";
import { claudeCode } from "@ai-hero/sandcastle/agents/claude-code";
import { podman } from "@ai-hero/sandcastle/sandboxes/podman";

const result = await run({
  agent: claudeCode("claude-opus-4-8", {
    env: {
      CLAUDE_CODE_USE_VERTEX: "1",
      CLOUD_ML_REGION: "global",
      ANTHROPIC_VERTEX_PROJECT_ID: "your-project-id",
    },
  }),
  sandbox: podman({
    selinuxLabel: "z",
    mounts: [
      { // ADC credentials
        hostPath: "~/.config/gcloud",
        sandboxPath: "/home/agent/.config/gcloud",
        readonly: true,
      },
    ],
  }),
  prompt: `Analyze pipeline: https://jenkins.eapqe.psi.redhat.com/...
    Run discover.py, then analyze each failed component...`,
  branchStrategy: { type: "head" },
});
```

> **Key insight:** With `branchStrategy: { type: "head" }`, Claude writes directly to the bind-mounted directory. Your `insights/` and `tmp/` directories appear on the host immediately. No branch/merge ceremony needed since your harness produces reports, not code changes.

### Option B: `createSandbox()` for multi-step orchestration

Create the sandbox once, run multiple Claude Code invocations inside it. This maps more closely to your current multi-agent workflow:

```typescript
import { createSandbox } from "@ai-hero/sandcastle";

const sandbox = await createSandbox({
  agent: claudeCode("claude-opus-4-8", { /* vertex env */ }),
  sandbox: podman({ /* mounts */ }),
  branchStrategy: { type: "head" },
});

// Step 1: Discovery
await sandbox.run({ prompt: "Run discover.py for build URL..." });

// Step 2: Run tests or check output between steps
const { stdout } = await sandbox.exec("ls tmp/*/manifest-*.yaml");

// Step 3: Analysis
await sandbox.run({ prompt: "Analyze all failed components..." });

// Step 4: Synthesis
await sandbox.run({ prompt: "Write pipeline summary..." });

await sandbox.close();
```

**Option A is simpler** -- Claude Code already knows how to orchestrate multi-step work via its Task tool internally. Option B gives you programmatic control between steps (e.g., checking that discovery succeeded before analysis). For your first attempt, start with Option A.

## 6. What Goes in the Containerfile

Sandcastle generates a default `Containerfile` via `sandcastle init`, but yours needs extra dependencies:

```dockerfile
FROM node:22-slim

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl jq \
    python3 python3-pip \
    default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
RUN pip3 install --break-system-packages pyyaml

# GitHub CLI (used by Sandcastle internally)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Non-root user (matches Sandcastle's default containerUid=1000)
RUN useradd -m -u 1000 -s /bin/bash agent
USER agent
WORKDIR /home/agent/workspace
```

> **Jenkins CLI JAR:** Your `discover.py` uses a Jenkins CLI JAR. You have two options:
>
> - **Mount it** from host via `mounts: [{ hostPath: "~/Workspace/jenkins-cli", sandboxPath: "/home/agent/jenkins-cli", readonly: true }]`
> - **Bake it** into the Containerfile with a `COPY` or `curl` download
>
> Mounting is simpler and keeps the image generic. Update your `.env` inside the container to point to the mounted path.

## 7. What's Next

Now that you understand the architecture, the next lesson will be hands-on:

1. Run `sandcastle init` in your project with the Podman provider
2. Customize the generated Containerfile
3. Build the image
4. Write a minimal orchestration script
5. Do a test run with a real pipeline URL

> **Before next session:** Make sure these are ready:
>
> ```bash
> # Verify Podman works
> podman run --rm hello-world
>
> # Verify ADC credentials
> ls ~/.config/gcloud/application_default_credentials.json
>
> # Verify your GCP project ID
> gcloud config get-value project
>
> # Install Sandcastle
> cd ~/Workspace/qe/agentic-insight-into-test-pipeline-results
> npm init -y  # if no package.json exists
> npm install @ai-hero/sandcastle
> ```

---

*Lesson 1 of Sandcastle + Podman series | Sources: [Sandcastle repo](https://github.com/mattpocock/sandcastle) | [Claude Code Vertex docs](https://code.claude.com/docs/en/google-vertex-ai) | [podman.ts source](https://github.com/mattpocock/sandcastle/blob/main/src/sandboxes/podman.ts)*
