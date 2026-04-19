# frozen_string_literal: true

require "cli/ui"
require_relative "restack"

module GT
  module Commands
    class Modify
      def initialize(args)
        @args = args
      end

      def run
        current = Git.current_branch
        stack = Stack.ordered

        unless stack.include?(current)
          ::CLI::UI.puts("{{red:Current branch is not part of a gt stack}}")
          exit 1
        end

        # Stage tracked files and amend
        Git.run("add", "-u")
        begin
          Git.run("commit", "--amend", "--no-edit")
        rescue Git::Error => e
          ::CLI::UI.puts("{{red:Amend failed: #{e.message}}}")
          exit 1
        end

        ::CLI::UI.puts("{{green:Amended}} {{bold:#{current}}}")

        # Force push current branch
        begin
          Git.run("push", "--force-with-lease", "origin", current)
        rescue Git::Error => e
          ::CLI::UI.puts("{{yellow:Push failed for #{current}: #{e.message}}}")
        end

        # Restack the whole stack (will end on original branch via restack logic)
        Restack.new([]).run

        # Move to the tip of the stack
        tip = Stack.ordered.last
        Git.run("checkout", tip) if tip && tip != Git.current_branch
        ::CLI::UI.puts("{{green:Now on tip:}} {{bold:#{tip}}}")
      end
    end
  end
end
