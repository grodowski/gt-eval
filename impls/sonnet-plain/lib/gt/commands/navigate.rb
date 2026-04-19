# frozen_string_literal: true

module GT
  module Commands
    class Navigate
      def initialize(direction, dir: nil)
        @direction = direction
        @dir       = dir
      end

      def run
        current = Git.current_branch(dir: @dir)
        stack   = Stack.new(dir: @dir)

        result, idx = stack.locate(current)

        if result.nil?
          $stderr.puts ::CLI::UI.fmt("{{red:Not in a gt-managed stack}}")
          exit 1
        end

        target = case @direction
                 when :up
                   next_branch = result[idx + 1]
                   if next_branch.nil?
                     $stderr.puts ::CLI::UI.fmt("{{yellow:Already at the top of the stack}}")
                     exit 1
                   end
                   next_branch
                 when :down
                   if idx == 0
                     $stderr.puts ::CLI::UI.fmt("{{yellow:Already at the bottom of the stack}}")
                     exit 1
                   end
                   result[idx - 1]
                 when :top
                   result.last
                 end

        if target == current
          puts ::CLI::UI.fmt("{{yellow:Already on #{target}}}")
          return
        end

        Git.run("git", "checkout", target, dir: @dir)
        puts ::CLI::UI.fmt("{{green:Switched to}} {{bold:#{target}}}")
      end
    end
  end
end
