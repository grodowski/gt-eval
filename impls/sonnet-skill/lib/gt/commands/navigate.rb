require "cli/ui"
require_relative "../git"

module GT
  module Commands
    class Up
      def initialize(argv)
        @argv = argv
      end

      def run
        current = Git.current_branch
        stack   = Git.stack_for(current)

        unless stack
          ::CLI::UI.puts "{{red:Not in a gt stack}}"
          exit 1
        end

        idx = stack.index(current)
        if idx.nil? || idx >= stack.size - 1
          ::CLI::UI.puts "{{yellow:Already at the top of the stack}}"
          exit 1
        end

        target = stack[idx + 1]
        Git.run("git", "checkout", target)
        ::CLI::UI.puts "{{green:Moved up to #{target}}}"
      end
    end

    class Down
      def initialize(argv)
        @argv = argv
      end

      def run
        current = Git.current_branch
        stack   = Git.stack_for(current)

        unless stack
          ::CLI::UI.puts "{{red:Not in a gt stack}}"
          exit 1
        end

        idx = stack.index(current)
        if idx.nil? || idx == 0
          ::CLI::UI.puts "{{yellow:Already at the bottom of the stack}}"
          exit 1
        end

        target = stack[idx - 1]
        Git.run("git", "checkout", target)
        ::CLI::UI.puts "{{green:Moved down to #{target}}}"
      end
    end

    class Top
      def initialize(argv)
        @argv = argv
      end

      def run
        current = Git.current_branch
        stack   = Git.stack_for(current)

        unless stack
          ::CLI::UI.puts "{{red:Not in a gt stack}}"
          exit 1
        end

        target = stack.last
        if target == current
          ::CLI::UI.puts "{{yellow:Already at the top of the stack}}"
          exit 1
        end

        Git.run("git", "checkout", target)
        ::CLI::UI.puts "{{green:Moved to top: #{target}}}"
      end
    end
  end
end
