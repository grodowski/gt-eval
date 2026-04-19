# frozen_string_literal: true

module GT
  module Commands
    module Modify
      module_function

      def run(_args)
        current = Git.current_branch

        # Stage tracked files and amend
        Git.run("add", "-u")
        Git.run("commit", "--amend", "--no-edit")

        # Force push the current branch
        begin
          Git.run("push", "--force-with-lease", "origin", current)
        rescue RuntimeError => e
          $stderr.puts "Warning: push failed: #{e.message}"
        end

        # Restack the whole stack
        require_relative "restack"
        Restack.run([])
      end
    end
  end
end
