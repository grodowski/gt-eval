# frozen_string_literal: true

require_relative "restack"

module GT
  module Commands
    class Modify
      def initialize(argv, dir: nil)
        @dir     = dir
        @message = nil
        parse!(argv)
      end

      def run
        current = Git.current_branch(dir: @dir)
        stack   = Stack.new(dir: @dir)

        # Stage tracked files and amend HEAD
        ::CLI::UI::Spinner.spin("Staging tracked files") do |spinner|
          Git.run("git", "add", "-u", dir: @dir)
          spinner.update_title("Staged tracked files")
        end

        ::CLI::UI::Spinner.spin("Amending HEAD") do |spinner|
          amend_args = ["git", "commit", "--amend", "--no-edit"]
          amend_args = ["git", "commit", "--amend", "-m", @message] if @message
          Git.run(*amend_args, dir: @dir)
          spinner.update_title("Amended HEAD on #{current}")
        end

        # Force push current branch
        if Git.remote_exists?("origin", dir: @dir)
          ::CLI::UI::Spinner.spin("Force-pushing #{current}") do |spinner|
            Git.run("git", "push", "--force-with-lease", "origin", current, dir: @dir)
            spinner.update_title("Force-pushed #{current}")
          end
        end

        # Restack the whole stack
        ordered = stack.ordered_stack(current)
        if ordered && ordered.length > 1
          restack = Commands::Restack.new([], dir: @dir)
          restack.restack_ordered(ordered)
        end

        # End on the tip
        tip = ordered ? ordered.last : current
        Git.run("git", "checkout", tip, dir: @dir) unless tip == Git.current_branch(dir: @dir)

        puts ::CLI::UI.fmt("{{green:✓}} Modified and restacked. On {{bold:#{tip}}}")
      end

      private

      def parse!(argv)
        argv = argv.dup
        while (arg = argv.shift)
          case arg
          when "-m", "--message"
            @message = argv.shift
          end
        end
      end
    end
  end
end
