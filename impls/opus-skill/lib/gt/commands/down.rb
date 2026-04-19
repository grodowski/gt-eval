# frozen_string_literal: true

module GT
  module Commands
    module Down
      module_function

      def run(_args)
        current = Git.current_branch
        parent = Git.parent_of(current)

        unless parent
          $stderr.puts "Already at the bottom of the stack."
          exit 1
        end

        Git.run("checkout", parent)
        puts "Moved down to #{parent}"
      end
    end
  end
end
