# Teaching Ralph Loops in 10 Minutes

*A presentation prep guide -- structuring your demo, building the scripts, and handling Q&A.*

## 1. The Core Story

Every good 10-minute demo has **one story**, not a feature tour. Your story is:

> **"You have test plans full of manual experiment descriptions. Ralph turns them into runnable bash scripts while you do something else."**

This works because it's a pain point your audience *already has*. You're not selling an abstract tool -- you're solving Tuesday's problem. ([Storylane: demo presentation guide](https://www.storylane.io/blog/how-to-prepare-a-great-software-demo-presentation) -- "solve their stated problem within the first 5 minutes")

## 2. Why Ralph Loops

This is the "why should I care" section you deliver in the first two minutes after firing off the demo. Three things the audience needs to understand:

### The name

Named after **Ralph Wiggum** from The Simpsons by [Geoffrey Huntley (July 2025)](https://www.atcyrus.com/stories/ralph-wiggum-technique-claude-code-autonomous-loops). Ralph's contributions to a scene are usually a single repeated line. Same energy: one condition, one job, infinite turns until done.

(Also: "ralph" is slang for vomiting -- Huntley said the realization of how cheap autonomous code generation had become made him want to.)

### Why not just prompt the agent interactively?

| Interactive session | Ralph loop |
|---|---|
| Context grows with every turn -- eventually the agent gets confused by its own earlier mistakes | **Fresh context every iteration** -- no context bloat |
| You babysit every step | Filesystem is the memory, not conversation history |
| You go home, the work stops | You walk away, the work continues |

The key insight: **the agent checks what's on disk, does the next task, writes back to disk, and exits**. The bash loop starts a brand-new agent. No accumulated confusion. ([Lushbinary: Loop Engineering Guide](https://lushbinary.com/blog/loop-engineering-ai-coding-agents-guide/) -- "design loops that prompt your agents")

### How is `/goal` different?

**Ralph (bash loop):** Each iteration = brand-new Claude instance. Memory lives in git, files on disk, progress markers. Fresh context window every time.

**`/goal`:** Official Anthropic equivalent. Runs inside *one growing session* with a stop hook. A separate lightweight model (Haiku) checks if you're done after each turn. No fresh context -- conversation keeps growing.

**For your presentation:** You're showing the bash loop. It's simpler to explain, the mechanics are visible (it's just a for loop), and the fresh-context-per-iteration design is what makes it work for long overnight runs.

([Awesome Claude: Ralph Wiggum Loop guide](https://awesomeclaude.ai/ralph-wiggum) | [DeskTheory: /goal vs /loop](https://desktheory.com/workflows/goal-vs-loop-claude-code))

> **Presentation tip:** In your talk, keep the /goal comparison to **one sentence**: "There's also a built-in `/goal` command that does something similar inside one session. The bash version gives you fresh context each round, which is better for long runs." Don't go deeper -- it's a rabbit hole.

## 3. The 10-Minute Timeline

### 0:00 -- 0:30 | Fire It Off

Open terminal. Run `./once.sh`. Say: **"I just kicked off something. It'll work in the background while I explain what's happening."**

The timestamped output starts scrolling. Leave it visible in a side terminal or second monitor. This is your live prop for the rest of the talk.

A single iteration takes ~10-12 minutes -- roughly the length of your talk. By the time you finish explaining, it's done or nearly done.

### 0:30 -- 2:30 | The Problem + Why Ralph

Switch to the test plan on screen. Read one experiment aloud:

*"Build-time enhance an application with a different Hibernate ORM version than the one in EAP. Verify deployment fails with a clear version mismatch error message."*

Then say: **"How long would it take you to turn all six of these into runnable bash scripts? An afternoon? That thing running in the other terminal is doing it right now."**

Now name the pattern: **"This is called a Ralph loop -- named after Ralph Wiggum. A bash for-loop that runs Claude, checks the result, and repeats. Each round gets a fresh brain -- no context bloat. The filesystem is the memory."**

One sentence on /goal if someone asks: "There's a built-in `/goal` command that does something similar inside one session. The bash version gives you fresh context each round."

### 2:30 -- 5:00 | The Three Files

Show the directory structure. **Three files, that's it.**

- `manual-tests.md` -- the extracted manual test descriptions (input)
- `prompt.md` -- what you're asking Claude to do (instructions)
- `once.sh` -- the single iteration you just launched (engine)

Spend the most time on `prompt.md` -- this is where the audience learns the pattern. Walk through the workflow steps, the PASS/FAIL/ERROR distinction, and the completion promise.

The bash script is ~10 lines. **"The prompt is where the intelligence lives. The bash is just plumbing."**

### 5:00 -- 7:00 | The Loop -- from once.sh to afk.sh

Show `afk.sh`: "once.sh does one experiment. afk.sh calls once.sh in a loop. `./afk.sh 6` -- six experiments, walk away, come back to a directory of scripts and results."

Show the **completion promise** in one sentence: "Claude writes RALPH_COMPLETE when all experiments have scripts. The loop greps for it. The bash decides when to stop, not the AI."

This is where you earn "I could do this myself" -- the audience sees the pattern is *simple enough to modify*.

### 7:00 -- 8:30 | Check Back on the Live Run

Switch to the terminal with `once.sh` output. By now it should have produced something -- a script in `output/` and a result in `results/`.

**Open the generated script** and walk through it. The audience sees: it's real, it's readable, it references the right paths.

**Open the results file**: "It didn't just write the script -- it ran it and told me what happened. PASS, FAIL, or ERROR."

**Safety net:** If it's still running or failed, switch to `output-backup/`: "Network's being slow -- here's what it produced when I ran it this morning."

### 8:30 -- 10:00 | Leave-Behind + Q&A

Show a slide (or just a terminal) with:

- A git repo / shared directory where they can grab the three files
- One-liner to try: `./once.sh`
- "Swap `manual-tests.md` for your own test plan. Change the prompt. That's it."

End with: **"The hardest part is writing a good prompt. Everything else is 15 lines of bash."**

## 3. Building the Demo Scripts

You need three files in a clean demo directory. Here's what each should look like:

### Directory structure

```
ralph-demo/
  manual-tests.md     # extracted from test plan
  prompt.md           # task instructions for Claude
  once.sh             # single iteration (for live demo)
  afk.sh              # full loop (show but don't run live)
  output/             # where generated scripts land
  output-backup/      # pre-generated safety net
```

### manual-tests.md

Extract just the manual tests section from EAP7-1648.adoc. Keep it clean -- no asciidoc markup, just the experiment descriptions:

```markdown
# Manual Test Experiments: EAP7-1648

## Experiment 1: Happy Path
Build with hibernate-enhance-maven-plugin, deploy to EAP,
confirm enhancement is active, lazy loading works.

## Experiment 2: Runtime Enhancement Baseline
Deploy the same app WITHOUT build-time enhancement.
Confirm the runtime enhancer activates.

## Experiment 3: Version Mismatch
Build with a DIFFERENT Hibernate version than EAP ships.
Deploy and verify the mismatch is detected with error:
"Mismatch between Hibernate version used for bytecode
enhancement (%s) and runtime (%s)"

## Experiment 4: Ant Enhancement
Enhance compiled classes using Hibernate's Ant EnhancementTask.
Deploy to EAP and confirm enhancement is active.
```

### prompt.md

This is the heart of the demo. Keep it short -- the audience needs to read it in 30 seconds.

```markdown
# Task
Read manual-tests.md. For each experiment that does NOT yet
have a script in output/, write a runnable bash script.

Each script should:
- Be self-contained (no external dependencies beyond EAP + Maven)
- Print clear PASS/FAIL at the end
- Include comments explaining what it verifies

When all experiments have scripts in output/, emit:
RALPH_COMPLETE
```

> **Presentation tip:** When you show this file, **read the last line aloud**: "When all experiments have scripts, emit RALPH_COMPLETE." Then say: "That's the completion promise. The bash loop greps for this string. That's how it knows to stop." This is the one concept you need them to remember.

### once.sh (single iteration)

```bash
#!/bin/bash
prompt=$(cat prompt.md)
claude --permission-mode acceptEdits -p "$prompt"
```

Yes, it's three lines. That's the point. Don't complicate it for the demo.

### afk.sh (full loop -- show, don't run)

```bash
#!/bin/bash
set -eo pipefail
[ -z "$1" ] && echo "Usage: $0 <iterations>" && exit 1

for ((i=1; i<=$1; i++)); do
  echo "=== Iteration $i of $1 ==="
  prompt=$(cat prompt.md)
  result=$(claude --print --permission-mode acceptEdits -p "$prompt")

  echo "$result"

  if echo "$result" | grep -q "RALPH_COMPLETE"; then
    echo "Done after $i iterations."
    exit 0
  fi
done
```

> **Try this:** Before the talk, run `./once.sh` at least three times to see how consistent the output is. Save the best run to `output-backup/` as your safety net. Note how long a single iteration takes -- you need this to time your narration during the live demo.

## 4. Common Pitfalls for Live AI Demos

| Don't | Do |
|---|---|
| Run the full loop live (too slow, unpredictable) | Use `once.sh` for live, mention `afk.sh` verbally |
| Show your real Claude API key or billing | Have `output-backup/` ready |
| Explain headless mode flags in detail | Increase terminal font to 18pt+ |
| Apologize if Claude produces imperfect output -- say "this is a first draft, you'd review it" | Keep a plain terminal -- no fancy prompts or colors that distract |
| Demo on conference wifi without a backup | Narrate while Claude works -- silence kills momentum |

([GitNation: Elio Struyf on scripting demos](https://gitnation.com/contents/improve-your-presentation-skills-by-scripting-your-live-coding-demos-to-perfection) -- minimize distractions, prepare fallbacks)

## 5. Handling Q&A

You'll likely get these questions. Have a one-liner ready for each:

### "Isn't this expensive?"

**Answer:** "A single iteration costs roughly the same as a coffee. If it saves you an afternoon of writing scripts, the math works."

*If pressed on specifics: Opus is ~$15/75 per million tokens in/out. A typical iteration with a test plan prompt + generated scripts might use 5-10k tokens total -- pennies.*

### "What if it writes bad scripts?"

**Answer:** "Same as any code review -- you read it before you run it. Ralph produces a first draft, not a final product."

### "How is this different from just chatting with Claude?"

**Answer:** "Two things: it writes directly to your filesystem, and the loop means it can tackle multiple items without you babysitting each one."

### "Can I run this overnight?"

**Answer:** "Yes, that's what afk.sh is for. Set the iteration count, walk away. For serious overnight runs you'd add container isolation, but that's a topic for another time."

## 6. Rehearsal Checklist

**Q: When should you run `once.sh` during the presentation?**

<details>
<summary>Show answer</summary>

**First thing -- let it run while you talk.** A single iteration takes ~10-12 minutes -- roughly the length of your talk. Fire it off first, explain while it runs, check back at the end. The scrolling output is your live prop. Don't wait until the end (the audience watches a blank terminal) and don't skip it (live demos build trust).

</details>

---

**Q: What's the ONE concept you need the audience to walk away with?**

<details>
<summary>Show answer</summary>

**The completion promise -- "Claude says DONE, the loop checks."** The loop checks for a marker. The prompt tells Claude when to emit it. That's the whole pattern. Not headless mode flags, not /goal differences, not token pricing.

</details>

## 7. Your Prep Steps

1. **Build the demo directory** with the four files above
2. **Do 3 dry runs** of `once.sh` -- note timing, save best output
3. **Time yourself** narrating the timeline above with a stopwatch
4. **Prepare the leave-behind** -- a shared directory or git repo with the three files + a one-paragraph README
5. **Test on the presentation machine** -- make sure Claude CLI is installed and authenticated

> **Next session:** In our next session, we'll actually build the demo scripts, do a dry run, and time the narration. Bring your stopwatch.
