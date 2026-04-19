# frozen_string_literal: true

module GT
  module Commands
    module Top
      module_function

      def run(_args)
        current = Git.current_branch

        # Walk up from current to find the tip
        tip = current
        loop do
          children = Stack.children_of(tip)
          break if children.empty?

          tip = children.first
        end

        if tip == current
          $stderr.puts "Already at the top of the stack."
          exit 1
        end

        Git.run("checkout", tip)
        puts "Moved to top: #{tip}"
      end
    end
  end
end
