# frozen_string_literal: true

module GT
  module Commands
    class Log
      def initialize(argv, dir: nil)
        @dir = dir
      end

      def run
        current = Git.current_branch(dir: @dir)
        stack   = Stack.new(dir: @dir)

        ordered = stack.ordered_stack(current)

        if ordered.nil? || ordered.empty?
          # Show a simple message — current branch has no stack
          puts ::CLI::UI.fmt("{{yellow:No gt-managed stack found for branch '#{current}'}}")
          puts ::CLI::UI.fmt("  Use {{bold:gt create <name>}} to start a stack.")
          return
        end

        # Find the base (parent of root) and include it as the stack root
        root        = ordered.first
        base_branch = Git.parent_of(root, dir: @dir) || "???"

        ([base_branch] + ordered).each do |branch|
          marker = branch == current ? "▶" : " "
          style  = branch == current ? "{{bold:{{green:#{branch}}}}}" : branch
          puts ::CLI::UI.fmt("  #{marker} #{style}")
        end
      end
    end
  end
end
