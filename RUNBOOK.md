# gt Benchmark Runbook

4 runs total: Sonnet + Opus × with/without `undercover` skill.

## Setup (once)

```sh
EVAL_DIR=$(cd "$(dirname "$0")" && pwd)

# Wipe impl directories and Claude project memories (ensures clean state)
for name in sonnet-plain sonnet-skill opus-plain opus-skill; do
  impl="$EVAL_DIR/impls/$name"
  rm -rf "$impl"
  project_key=$(echo "$impl" | sed 's|/|-|g' | sed 's|^-||')
  rm -rf ~/.claude/projects/$project_key
  mkdir -p "$impl"
done

# Plain runs: no plugin
for dir in "$EVAL_DIR/impls/sonnet-plain" "$EVAL_DIR/impls/opus-plain"; do
  mkdir -p "$dir/.claude"
  cp "$EVAL_DIR/agent_settings.json" "$dir/.claude/settings.json"
  git -C "$dir" init
done

# Skill runs: undercover plugin enabled + undercover gem from json-output-format branch
for dir in "$EVAL_DIR/impls/sonnet-skill" "$EVAL_DIR/impls/opus-skill"; do
  mkdir -p "$dir/.claude"
  cp "$EVAL_DIR/agent_settings.json" "$dir/.claude/settings.json"
  git -C "$dir" init
  git -C "$dir" commit --allow-empty -m "Initial commit"
  init_sha=$(git -C "$dir" rev-parse HEAD)
  echo "-c $init_sha" > "$dir/.undercover"
  cat > "$dir/Gemfile" <<'EOF'
source "https://rubygems.org"

gem "undercover", github: "grodowski/undercover", branch: "json-output-format"
EOF
  bundle install --gemfile="$dir/Gemfile"
  cat > "$dir/CLAUDE.md" <<'EOF'
Before doing anything else, invoke /undercover:coverage now. After every test run, follow the skill's coverage feedback loop to check for gaps and write tests until undercover exits 0.
EOF
done
```

## Running each agent

Open a separate terminal per run. From inside the impl directory:

```sh
EVAL_DIR=/path/to/gt-eval

# Sonnet, no skill
cd "$EVAL_DIR/impls/sonnet-plain"
claude --model claude-sonnet-4-6 < "$EVAL_DIR/starter_prompt.md"

# Sonnet, with skill
cd "$EVAL_DIR/impls/sonnet-skill"
claude --model claude-sonnet-4-6 --plugin-dir ~/dev/undercover-claude < "$EVAL_DIR/starter_prompt.md"

# Opus, no skill
cd "$EVAL_DIR/impls/opus-plain"
claude --model claude-opus-4-6 --effort high < "$EVAL_DIR/starter_prompt.md"

# Opus, with skill
cd "$EVAL_DIR/impls/opus-skill"
claude --model claude-opus-4-6 --effort high --plugin-dir ~/dev/undercover-claude < "$EVAL_DIR/starter_prompt.md"
```

> Skill runs have the `undercover` plugin enabled via `--plugin-dir` and
> a `CLAUDE.md` that instructs the agent to invoke `/undercover:coverage` at scaffold time.

## Measuring results (after each run)

```sh
EVAL_DIR=/path/to/gt-eval
ruby "$EVAL_DIR/measure.rb" "$EVAL_DIR/impls/sonnet-plain"
ruby "$EVAL_DIR/measure.rb" "$EVAL_DIR/impls/sonnet-skill"
ruby "$EVAL_DIR/measure.rb" "$EVAL_DIR/impls/opus-plain"
ruby "$EVAL_DIR/measure.rb" "$EVAL_DIR/impls/opus-skill"
```

## Running the harness against each

```sh
EVAL_DIR=/path/to/gt-eval
GT_BIN="$EVAL_DIR/impls/sonnet-plain/bin/gt" ruby "$EVAL_DIR/harness.rb"
GT_BIN="$EVAL_DIR/impls/sonnet-skill/bin/gt" ruby "$EVAL_DIR/harness.rb"
GT_BIN="$EVAL_DIR/impls/opus-plain/bin/gt" ruby "$EVAL_DIR/harness.rb"
GT_BIN="$EVAL_DIR/impls/opus-skill/bin/gt" ruby "$EVAL_DIR/harness.rb"
```

## Checking skill log

```sh
EVAL_DIR=/path/to/gt-eval
cat "$EVAL_DIR/impls/sonnet-skill/.claude/skill_log.txt"
cat "$EVAL_DIR/impls/opus-skill/.claude/skill_log.txt"
```

## Running the reviewer

Start a new Claude session and paste the contents of `reviewer_prompt.md`,
replacing `[PATH_A]` and `[PATH_B]` with two impl dirs you want to compare.

Run all 6 pairwise comparisons for a complete picture, or at minimum:
- sonnet-plain vs sonnet-skill
- opus-plain vs opus-skill
- sonnet-skill vs opus-skill
