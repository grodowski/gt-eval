require "cli/ui"
require_relative "../git"
require_relative "restack"

module GT
  module Commands
    class Sync
      def initialize(argv)
        @argv = argv
      end

      def run
        current = Git.current_branch

        ::CLI::UI.puts "Fetching origin..."
        out, err, status = Git.run("git", "fetch", "origin")
        unless status.success?
          ::CLI::UI.puts "{{yellow:git fetch failed: #{err}}}"
        end

        ::CLI::UI.puts "Updating main..."
        out, err, status = Git.run("git", "checkout", "main")
        unless status.success?
          ::CLI::UI.puts "{{red:Could not checkout main: #{err}}}"
          exit 1
        end

        out, err, status = Git.run("git", "merge", "--ff-only", "origin/main")
        unless status.success?
          ::CLI::UI.puts "{{red:Could not fast-forward main: #{err}}}"
          exit 1
        end

        # Return to original branch before restacking
        Git.run("git", "checkout", current)

        ::CLI::UI.puts "Restacking..."
        Restack.new([]).run
      end
    end
  end
end
