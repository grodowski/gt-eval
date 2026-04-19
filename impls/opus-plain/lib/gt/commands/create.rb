# frozen_string_literal: true

require "cli/ui"

module GT
  module Commands
    class Create
      def initialize(args)
        @name = nil
        @message = nil
        parse_args(args)
      end

      def run
        unless @name
          ::CLI::UI.puts("{{red:Usage: gt create <name> [-m <msg>]}}")
          exit 1
        end

        parent = Git.current_branch
        parent_sha = Git.rev_parse("HEAD")

        # Create and switch to new branch BEFORE committing
        Git.run("checkout", "-b", @name)

        # Stage tracked files and commit on the NEW branch
        msg = @message || @name
        Git.run("add", "-u")
        begin
          Git.run("commit", "-m", msg)
        rescue Git::Error
          # Nothing to commit is fine — branch may still be created
        end

        # Set gt metadata
        Git.set_gt_parent(@name, parent)
        Git.set_gt_fork_point(@name, parent_sha)

        # Push
        begin
          Git.run("push", "-u", "origin", @name)
        rescue Git::Error => e
          ::CLI::UI.puts("{{yellow:Push failed: #{e.message}}}")
        end

        # Open PR targeting parent
        create_pr(parent)

        ::CLI::UI.puts("{{green:Created branch}} {{bold:#{@name}}} {{green:on top of}} {{bold:#{parent}}}")
      end

      private

      def parse_args(args)
        i = 0
        while i < args.length
          case args[i]
          when "-m"
            @message = args[i + 1]
            i += 2
          else
            @name = args[i]
            i += 1
          end
        end
      end

      def create_pr(parent)
        result = GH.run("pr", "create", "--base", parent, "--head", @name,
                         "--title", @message || @name, "--body", "", "--fill")
        if result
          ::CLI::UI.puts("{{green:PR created}}")
        end
      end
    end
  end
end
