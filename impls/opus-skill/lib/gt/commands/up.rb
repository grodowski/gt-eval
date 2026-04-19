# frozen_string_literal: true

module GT
  module Commands
    module Up
      module_function

      def run(_args)
        current = Git.current_branch
        children = Stack.children_of(current)

        if children.empty?
          $stderr.puts "Already at the top of the stack."
          exit 1
        end

        Git.run("checkout", children.first)
        puts "Moved up to #{children.first}"
      end
    end
  end
end
