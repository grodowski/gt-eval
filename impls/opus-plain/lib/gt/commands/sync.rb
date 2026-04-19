# frozen_string_literal: true

require "cli/ui"
require_relative "restack"

module GT
  module Commands
    class Sync
      def initialize(args)
        @args = args
      end

      def run
        main = Git.main_branch
        original = Git.current_branch

        # Pull main
        ::CLI::UI.puts("Pulling {{bold:#{main}}}...")
        Git.run("checkout", main)
        begin
          Git.run("pull", "--ff-only", "origin", main)
        rescue Git::Error => e
          ::CLI::UI.puts("{{red:Failed to pull #{main}: #{e.message}}}")
          Git.run("checkout", original)
          exit 1
        end

        # Go back to original branch before restacking
        Git.run("checkout", original) unless original == main

        # Restack
        Restack.new([]).run
      end
    end
  end
end
