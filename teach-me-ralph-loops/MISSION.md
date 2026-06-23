# Mission: Teach Ralph Loops in a 10-Minute Live Presentation

## Why
Prepare and deliver a 10-minute live presentation to QE colleagues that demonstrates Ralph loops are easy to set up and useful for real QE work. The demo task -- turning manual test descriptions from a test plan into runnable bash scripts -- is chosen because every QE engineer has test plans full of manual experiments sitting around.

## Success looks like
- A rehearsed 10-minute presentation with a live Ralph demo that works reliably
- Audience leaves thinking "I could set that up myself this afternoon"
- A leave-behind (script + prompt template) colleagues can copy and adapt
- Comfortable handling the likely Q&A: cost, safety, "what if it writes bad tests"

## Constraints
- 10 minutes total -- tight; every minute must earn its place
- Mixed audience: some proficient with Claude Code, some not
- No containers -- run Ralph directly on host to keep demo simple
- Must work live (no pre-recorded fallback) -- needs a reliable demo path
- Demo uses real test plan content (EAP7-1648 manual tests section)

## Out of scope
- Container isolation (Podman setup) -- too much for 10 minutes
- `/goal` command details -- focus on the bash-based Ralph loop only
- Multi-agent orchestration or workflow scripts
- Teaching Claude Code basics (not the point of this talk)
