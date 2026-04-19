Build a Ruby CLI gem called `gt` for managing stacked pull requests (like Graphite).
Work in the current directory. Make incremental commits as you complete each feature.

## Stack model

Branches form a linear chain: `main → A → B → C`.

Each branch tracks its parent via git config:
- `branch.<name>.gt-parent` — name of the parent branch
- `branch.<name>.gt-fork-point` — SHA of the parent tip at the time this branch was created

Use these exact config keys.

## Commands to implement in order

1. `gt create <name> [-m <msg>]` — stage tracked files (`git add -u`), commit, create branch off current, push, open PR targeting parent
2. `gt log` (alias `gt ls`) — print the stack from root to tip, highlighting current branch
3. `gt up` / `gt down` / `gt top` — navigate the stack (exit 1 if no move possible)
4. `gt restack` — rebase each child onto its parent tip using `git rebase --onto`, force push, update PR descriptions with a stack comment
5. `gt sync` — pull main, then restack
6. `gt modify` (alias `gt m`) — amend HEAD (`git commit --amend`), force push, then restack

## Tech

- Ruby gem with `bin/gt` entry point
- Use `cli-ui ~> 2.7` for output (spinners, colors)
- Use `Open3.capture3` for all git and `gh` calls (array form, no shell interpolation)
- Tests with Minitest + a `GitSandbox` helper (tmpdir + bare remote per test)

## Notes

- `gt restack` from any branch in the stack should restack the whole stack
- `gt restack` with no gt-managed branches should exit 1
- `gt modify` amends the current branch, then restacks — ends on the tip of the stack
- All `gh` calls should degrade gracefully if `gh` is not installed

Work through the commands one at a time in the order listed. For each command:
1. Implement it
2. Write tests and make them pass
3. Commit

Do not move to the next command until the current one is committed. Start with the gem scaffold (gemspec, bin/gt, lib skeleton, test helper) as its own commit before implementing any commands.
