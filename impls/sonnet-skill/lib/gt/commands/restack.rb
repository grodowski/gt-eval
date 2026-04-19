require "cli/ui"
require_relative "../git"

module GT
  module Commands
    class Restack
      def initialize(argv)
        @argv = argv
      end

      def run
        current = Git.current_branch
        stack   = Git.stack_for(current)

        unless stack
          ::CLI::UI.puts "{{red:No gt-managed branches found. Nothing to restack.}}"
          exit 1
        end

        stack.each do |branch|
          restack_branch(branch)
        end

        # Return to the original branch
        Git.run("git", "checkout", current)
        ::CLI::UI.puts "{{green:Restack complete}}"
      end

      private

      def restack_branch(branch)
        parent     = Git.gt_parent(branch)
        fork_point = Git.gt_fork_point(branch)
        new_base   = Git.tip_sha(parent)

        if fork_point == new_base
          ::CLI::UI.puts "  #{branch}: already up to date"
          return
        end

        ::CLI::UI.puts "  Restacking #{branch} onto #{parent}..."

        out, err, status = Git.run(
          "git", "rebase", "--onto", new_base, fork_point, branch
        )
        unless status.success?
          ::CLI::UI.puts "{{red:Rebase failed for #{branch}: #{err}}}"
          exit 1
        end

        # Update the fork-point to the new parent tip
        Git.set_gt_fork_point(branch, new_base)

        # Force push the rebased branch
        out, err, status = Git.run("git", "push", "--force-with-lease", "origin", branch)
        unless status.success?
          ::CLI::UI.puts "{{yellow:Force push failed for #{branch}: #{err}}}"
        end

        # Update PR description with stack comment (requires gh, degrades gracefully)
        update_pr_description(branch)
      end

      def update_pr_description(branch)
        stack  = Git.stack_for(branch)
        parent = Git.gt_parent(branch)
        stack_body = stack.map do |b|
          b == branch ? "- **#{b}** (this PR)" : "- #{b}"
        end.join("\n")

        body = "<!-- gt-stack -->\n**Stack:**\n#{stack_body}\n<!-- /gt-stack -->"

        out, err, status = Git.run(
          "gh", "pr", "edit", branch,
          "--body", body
        )
        unless status.success?
          ::CLI::UI.puts "{{yellow:Could not update PR for #{branch}: #{err}}}"
        end
      end
    end
  end
end
