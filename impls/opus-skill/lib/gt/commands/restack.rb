# frozen_string_literal: true

module GT
  module Commands
    module Restack
      module_function

      def run(_args)
        branches = Stack.all_gt_branches

        if branches.empty?
          $stderr.puts "No gt-managed branches to restack."
          exit 1
        end

        # Find the full stack from any gt branch
        current = Git.current_branch
        start_branch = branches.include?(current) ? current : branches.first
        stack = Stack.full_stack_from(start_branch)

        stack.each do |branch|
          restack_branch(branch)
        end

        update_pr_descriptions(stack)

        # Move to the tip of the stack
        tip = stack.last
        Git.run("checkout", tip)
        puts "Restacked. Now on #{tip}."
      end

      def restack_branch(branch)
        parent = Git.parent_of(branch)
        return unless parent

        old_fork = Git.fork_point_of(branch)
        new_parent_tip = Git.rev_parse(parent)

        # Skip if already up to date
        return if old_fork == new_parent_tip

        Git.run("checkout", branch)
        Git.run("rebase", "--onto", new_parent_tip, old_fork, branch)
        Git.set_fork_point(branch, new_parent_tip)

        begin
          Git.run("push", "--force-with-lease", "origin", branch)
        rescue RuntimeError => e
          $stderr.puts "Warning: push failed for #{branch}: #{e.message}"
        end
      end

      def update_pr_descriptions(stack)
        return unless Git.gh_available?

        base = Git.parent_of(stack.first) || Git.main_branch
        stack_comment = build_stack_comment(stack, base)

        stack.each do |branch|
          begin
            Git.gh("pr", "edit", branch, "--body", stack_comment)
          rescue RuntimeError
            # PR might not exist yet
          end
        end
      end

      def build_stack_comment(stack, base)
        lines = ["**Stack:**", ""]
        lines << "- `#{base}` (base)"
        stack.each do |branch|
          lines << "- `#{branch}`"
        end
        lines.join("\n")
      end
    end
  end
end
