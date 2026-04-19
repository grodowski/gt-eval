require "cli/ui"
require_relative "../git"

module GT
  module Commands
    class Create
      def initialize(argv)
        @name    = argv.shift
        @message = nil
        until argv.empty?
          flag = argv.shift
          @message = argv.shift if flag == "-m"
        end
      end

      def run
        unless @name
          ::CLI::UI.puts "{{red:Usage: gt create <name> [-m <message>]}}"
          exit 1
        end

        parent = Git.current_branch
        unless parent
          ::CLI::UI.puts "{{red:Could not determine current branch}}"
          exit 1
        end

        fork_point = Git.tip_sha(parent)
        unless fork_point
          ::CLI::UI.puts "{{red:Could not determine tip of #{parent}}}"
          exit 1
        end

        # Stage all tracked modified files
        out, err, status = Git.run("git", "add", "-u")
        unless status.success?
          ::CLI::UI.puts "{{red:git add -u failed: #{err}}}"
          exit 1
        end

        # Create the new branch from the current branch
        out, err, status = Git.run("git", "checkout", "-b", @name)
        unless status.success?
          ::CLI::UI.puts "{{red:git checkout -b #{@name} failed: #{err}}}"
          exit 1
        end

        # Commit with provided message, or branch name as default
        msg = @message || @name
        out, err, status = Git.run("git", "commit", "-m", msg, "--allow-empty")
        unless status.success?
          ::CLI::UI.puts "{{red:git commit failed: #{err}}}"
          exit 1
        end

        # Set gt tracking metadata
        Git.set_gt_parent(@name, parent)
        Git.set_gt_fork_point(@name, fork_point)

        # Push the new branch
        out, err, status = Git.run("git", "push", "-u", "origin", @name)
        unless status.success?
          ::CLI::UI.puts "{{yellow:git push failed: #{err}}}"
        end

        # Open PR (requires gh; degrade gracefully if not installed)
        open_pr(parent)

        ::CLI::UI.puts "{{green:Created branch #{@name} off #{parent}}}"
      end

      private

      def open_pr(parent)
        args = ["gh", "pr", "create",
                "--base", parent,
                "--head", @name,
                "--title", @message || @name,
                "--body", ""]
        out, err, status = Git.run(*args)
        if status.success?
          ::CLI::UI.puts "{{green:PR created: #{out}}}"
        else
          ::CLI::UI.puts "{{yellow:Could not open PR (gh may not be installed or authenticated): #{err}}}"
        end
      end
    end
  end
end
