# frozen_string_literal: true

require "cli/ui"

module GT
  module Commands
    class Up
      def initialize(args)
        @args = args
      end

      def run
        current = Git.current_branch
        stack = Stack.ordered
        idx = stack.index(current)

        if idx.nil? || idx >= stack.length - 1
          ::CLI::UI.puts("{{red:Already at the top of the stack}}")
          exit 1
        end

        target = stack[idx + 1]
        Git.run("checkout", target)
        ::CLI::UI.puts("{{green:Switched to}} {{bold:#{target}}}")
      end
    end
  end
end
