# gt Implementation Reviewer

You are evaluating two independent implementations of `gt`, a Ruby CLI for stacked pull requests.

Implementation A is at: **[PATH_A]**
Implementation B is at: **[PATH_B]**

The `simplify` skill was active for one of them. Determine which one based on your review.

---

## Step 1: Run automated metrics

Run this for each implementation and paste the output into your report:

```sh
ruby ~/dev/gt-eval/measure.rb [PATH_A]
ruby ~/dev/gt-eval/measure.rb [PATH_B]
```

---

## Step 2: Run the harness

```sh
GT_BIN=[PATH_A]/bin/gt ruby ~/dev/gt-eval/harness.rb
GT_BIN=[PATH_B]/bin/gt ruby ~/dev/gt-eval/harness.rb
```

Note how many attempts each took to reach a passing harness (check git log for "fix" commits after the initial implementation).

---

## Step 3: Code quality review

For each implementation, score 1–5 and give a one-line justification:

**Structure** — separation between git ops / GitHub API / CLI dispatch / command logic
- Are commands in separate files or one blob?
- Is there obvious duplication that should have been extracted?

**Error handling**
- `gh` not installed?
- Running outside a gt-tracked stack?
- Are `Open3.capture3` results checked or swallowed?

**Simplicity**
- Abstractions that don't earn their complexity?
- Methods doing too many things?
- Easy to follow without comments?

---

## Step 4: Test quality review

Score 1–5:

- Real git sandbox (tmpdir + bare remote) or everything mocked?
- Do tests actually fail if you break a method? (spot-check one)
- Edge cases covered: empty stack, no `gh`, conflict during restack?
- Vacuous tests (stub too much, assert too little)?

---

## Step 5: Git history

```sh
git -C [PATH_A] log --oneline
git -C [PATH_B] log --oneline
```

- Incremental commits or big-bang dumps?
- Any "cleanup", "simplify", or "refactor" commits not directly requested? Flag these — they signal the `simplify` skill ran.
- Does the history tell a coherent story?

---

## Step 6: Spec fidelity

Check each item for both implementations:

| Spec requirement | A | B |
|---|---|---|
| Git config key `branch.<name>.gt-parent` | ✓/✗ | ✓/✗ |
| Command `gt log` (not `gt stack`) | ✓/✗ | ✓/✗ |
| Command `gt modify` (not `gt amend`) | ✓/✗ | ✓/✗ |
| `gt modify` ends on stack tip after restack | ✓/✗ | ✓/✗ |
| `gt restack` exits 1 with no gt branches | ✓/✗ | ✓/✗ |
| `Open3.capture3` array form (not shell strings) | ✓/✗ | ✓/✗ |

---

## Step 7: Verdict

Fill in this summary table:

| Metric | A | B |
|---|---|---|
| Harness: tests passing (of 16) | | |
| Harness: attempts to pass | | |
| Commits | | |
| Lib LOC | | |
| Test LOC | | |
| Test count | | |
| Test/impl ratio | | |
| Total tool calls | | |
| Test runs mid-session | | |
| Approx cost ($) | | |
| Simplify invocations | | |
| Code quality score (1–5) | | |
| Test quality score (1–5) | | |
| Spec fidelity (of 6) | | |

Then answer:
- Which implementation is more correct?
- Which has better code quality?
- Which has better tests?
- Which do you think had the `simplify` skill active, and why?
- Did the skill help or hurt (speed, quality, cost)?
- What is the single biggest difference between the two?
