require "cli/ui"
require_relative "../git"
require_relative "restack"

module GT
  module Commands
    class Modify
      def initialize(argv)
        @message = nil
        until argv.empty?
          flag = argv.shift
          @message = argv.shift if flag == "-m"
        end
      end

      def run
        current = Git.current_branch

        # Amend the HEAD commit
        amend_args = ["git", "commit", "--amend"]
        if @message
          amend_args += ["--message", @message]
        else
          amend_args << "--no-edit"
        end

        out, err, status = Git.run(*amend_args)
        unless status.success?
          ::CLI::UI.puts "{{red:git commit --amend failed: #{err}}}"
          exit 1
        end

        # Force push the amended branch
        out, err, status = Git.run("git", "push", "--force-with-lease", "origin", current)
        unless status.success?
          ::CLI::UI.puts "{{yellow:Force push failed for #{current}: #{err}}}"
        end

        # Restack the whole stack
        Restack.new([]).run

        # Navigate to the tip of the stack
        stack = Git.stack_for(current)
        if stack && stack.last != Git.current_branch
          Git.run("git", "checkout", stack.last)
          ::CLI::UI.puts "{{green:Moved to tip: #{stack.last}}}"
        end
      end
    end
  end
end
