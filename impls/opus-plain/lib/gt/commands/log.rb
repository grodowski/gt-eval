# frozen_string_literal: true

require "cli/ui"

module GT
  module Commands
    class Log
      def initialize(args)
        @args = args
      end

      def run
        stack = Stack.ordered
        current = Git.current_branch
        main = Git.main_branch

        if stack.empty?
          ::CLI::UI.puts("{{yellow:No gt-managed branches found}}")
          return
        end

        # Print main as the base
        if current == main
          ::CLI::UI.puts("{{cyan:* #{main}}} (base)")
        else
          ::CLI::UI.puts("  #{main} (base)")
        end

        stack.each_with_index do |branch, i|
          connector = i == stack.length - 1 ? "└─" : "├─"
          if branch == current
            ::CLI::UI.puts("{{cyan:#{connector} * #{branch}}}")
          else
            ::CLI::UI.puts("#{connector}   #{branch}")
          end
        end
      end
    end
  end
end
