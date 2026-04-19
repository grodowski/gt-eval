# frozen_string_literal: true

module GT
  module Commands
    module Sync
      module_function

      def run(_args)
        current = Git.current_branch

        # Pull main
        begin
          Git.run("fetch", "origin")
          Git.run("checkout", Git.main_branch)
          Git.run("merge", "--ff-only", "origin/#{Git.main_branch}")
        rescue RuntimeError => e
          $stderr.puts "Warning: failed to sync main: #{e.message}"
        end

        # Switch back if we moved
        Git.run("checkout", current) if Git.current_branch != current

        # Restack
        require_relative "restack"
        Restack.run([])
      end
    end
  end
end
