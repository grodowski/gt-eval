# frozen_string_literal: true

require "cli/ui"

module GT
  module Commands
    class Restack
      def initialize(args)
        @args = args
      end

      def run
        stack = Stack.ordered

        if stack.empty?
          ::CLI::UI.puts("{{red:No gt-managed branches to restack}}")
          exit 1
        end

        original_branch = Git.current_branch

        stack.each do |branch|
          rebase_branch(branch)
        end

        # Update PR descriptions with stack info
        update_pr_descriptions(stack)

        # Return to original branch (or tip if original was not in stack)
        target = stack.include?(original_branch) ? original_branch : stack.last
        Git.run("checkout", target)

        ::CLI::UI.puts("{{green:Stack restacked successfully}}")
      end

      private

      def rebase_branch(branch)
        parent = Git.gt_parent(branch)
        return unless parent

        old_fork_point = Git.gt_fork_point(branch)
        new_parent_tip = Git.rev_parse(parent)

        # Skip if already up to date
        if old_fork_point == new_parent_tip
          ::CLI::UI.puts("  {{bold:#{branch}}} — already up to date")
          return
        end

        ::CLI::UI.puts("  Restacking {{bold:#{branch}}} onto {{bold:#{parent}}}")

        Git.run("checkout", branch)
        begin
          Git.run("rebase", "--onto", new_parent_tip, old_fork_point, branch)
        rescue Git::Error => e
          # Abort rebase on conflict
          Git.run_safe("rebase", "--abort")
          ::CLI::UI.puts("{{red:Rebase conflict for #{branch}: #{e.message}}}")
          ::CLI::UI.puts("{{red:Restack aborted}}")
          exit 1
        end

        # Update fork point
        Git.set_gt_fork_point(branch, new_parent_tip)

        # Force push
        begin
          Git.run("push", "--force-with-lease", "origin", branch)
        rescue Git::Error => e
          ::CLI::UI.puts("{{yellow:Push failed for #{branch}: #{e.message}}}")
        end
      end

      def update_pr_descriptions(stack)
        return unless GH.available?

        stack_comment = build_stack_comment(stack)

        stack.each do |branch|
          GH.run("pr", "edit", branch, "--body", stack_comment)
        end
      end

      def build_stack_comment(stack)
        current = Git.current_branch
        lines = ["**Stack:**", ""]
        main = Git.main_branch
        lines << "- `#{main}` (base)"
        stack.each do |branch|
          marker = branch == current ? " **\u2190 you are here**" : ""
          lines << "- `#{branch}`#{marker}"
        end
        lines.join("\n")
      end
    end
  end
end
