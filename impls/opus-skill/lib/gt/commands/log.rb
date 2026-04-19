# frozen_string_literal: true

require "cli/ui"

module GT
  module Commands
    module Log
      module_function

      def run(_args)
        current = Git.current_branch
        branches = Stack.all_gt_branches

        if branches.empty?
          puts "No gt-managed branches found."
          return
        end

        # Find the stack containing the current branch, or show all stacks
        stack = if branches.include?(current)
                  Stack.full_stack_from(current)
                else
                  # Show from first root
                  root = Stack.find_root(branches.first)
                  Stack.ordered_stack(root)
                end

        # Find the base (parent of root)
        root = stack.first
        base = Git.parent_of(root) || Git.main_branch

        puts ::CLI::UI.fmt("{{cyan:#{base}}}")
        stack.each do |branch|
          if branch == current
            puts ::CLI::UI.fmt("  {{v}} {{green:#{branch}}} {{yellow:← HEAD}}")
          else
            puts ::CLI::UI.fmt("  {{*}} #{branch}")
          end
        end
      end
    end
  end
end
