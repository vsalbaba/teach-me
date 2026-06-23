# Task

Read `manual-tests.md`. Find the FIRST experiment that does NOT yet have a
script in `output/`. Write a runnable bash script for that ONE experiment only.

Name the script `output/<NN>-<slug>.sh` matching the experiment number.

## Workflow

1. Check `output/` for existing scripts
2. Find the first experiment without a script
3. Implement the script
4. Run the script
5. If the script ERRORS (syntax error, missing command, crash) -- fix it and re-run
6. If the script runs cleanly but the TEST FAILS -- that's a valid result, leave it
7. Write a results file `results/<NN>-<RESULT>-<slug>.md` with the test outcome
8. Commit the script into git (init if not a git repo)

One task at a time. Finish it before stopping.

## Results

After running a script, write `results/<NN>-<RESULT>-<slug>.md` with:
(e.g. `results/01-PASS-happy-path.md`, `results/03-FAIL-version-mismatch.md`)
- Experiment name
- Result: PASS, FAIL, or ERROR
- What happened -- key output, error messages, or observations
- If FAIL: what specifically did not match the expected behavior

These files are the human-readable record. A reviewer should be able to read
`results/` and understand what passed, what failed, and why -- without
re-running anything.

## Environment

The `sources/` directory contains:
- EAP binaries (server installation)
- Maven repository with productized Hibernate ORM artifacts

Scan `sources/` for more relevant repositories for existing patterns.

Scripts should reference `sources/` for all EAP and Maven dependencies. Do not
download anything from the internet -- everything needed is in `sources/`.

If you create an app to test a feature, save it to `output/<NN>-test-app-<slug>/`

## Script requirements

The script should:
- Be self-contained -- use only what's in `sources/` and standard tools (bash, maven, java)
- Set up any needed test application (pom.xml, entity classes, persistence.xml) inline or in a temp directory
- Build, deploy, and verify the experiment's expected outcome
- Include comments explaining what it verifies
- Use these exit codes and messages:
  - `PASS` + exit 0 -- the test ran and the feature behaves as expected
  - `FAIL` + exit 0 -- the test ran correctly but the feature did not behave as expected (this is a valid test result, not a script error)
  - `ERROR` + exit 1 -- the script itself broke (missing tool, syntax error, crash)

## Do NOT

- Do NOT delete or skip verification steps to make a script "pass"
- Do NOT modify this prompt or `manual-tests.md`
- Do NOT install system packages -- if a tool is missing, note it in
  `MISSING_TOOLS.md` with a one-line description and move to the next experiment

## Halt Condition

If ALL experiments already have scripts in `output/`, emit:
RALPH_COMPLETE

If a required tool is missing and no other experiments can be scripted, emit:
RALPH_COMPLETE
