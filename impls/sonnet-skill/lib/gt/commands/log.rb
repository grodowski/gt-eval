require "cli/ui"
require_relative "../git"

module GT
  module Commands
    class Log
      def initialize(argv)
        @argv = argv
      end

      def run
        current = Git.current_branch
        all     = Git.all_gt_branches

        if all.empty?
          ::CLI::UI.puts "{{yellow:No stacked branches found}}"
          exit 1
        end

        stack = Git.stack_for(current)
        unless stack&.include?(current)
          ::CLI::UI.puts "{{yellow:Current branch '#{current}' is not part of a gt stack}}"
          exit 1
        end

        root_parent = Git.gt_parent(stack.first)
        display_stack = root_parent ? [root_parent] + stack : stack

        display_stack.each do |branch|
          if branch == current
            ::CLI::UI.puts "{{cyan:* #{branch}}}"
          else
            ::CLI::UI.puts "  #{branch}"
          end
        end
      end
    end
  end
end
