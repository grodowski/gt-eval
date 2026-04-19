# frozen_string_literal: true

require "cli/ui"

module GT
  module Commands
    class Top
      def initialize(args)
        @args = args
      end

      def run
        stack = Stack.ordered

        if stack.empty?
          ::CLI::UI.puts("{{red:No gt-managed branches found}}")
          exit 1
        end

        current = Git.current_branch
        tip = stack.last

        if current == tip
          ::CLI::UI.puts("{{yellow:Already at the top of the stack}}")
          exit 1
        end

        Git.run("checkout", tip)
        ::CLI::UI.puts("{{green:Switched to}} {{bold:#{tip}}}")
      end
    end
  end
end
