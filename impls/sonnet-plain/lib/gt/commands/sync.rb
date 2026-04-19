# frozen_string_literal: true

require_relative "restack"

module GT
  module Commands
    class Sync
      def initialize(argv, dir: nil)
        @dir = dir
      end

      def run
        current = Git.current_branch(dir: @dir)

        # Determine the base branch (the root of the stack's parent, usually main)
        stack  = Stack.new(dir: @dir)
        base   = find_base(current, stack)

        unless base
          $stderr.puts ::CLI::UI.fmt("{{red:Could not determine base branch to sync}}")
          exit 1
        end

        # Pull base branch
        ::CLI::UI::Spinner.spin("Pulling #{base}") do |spinner|
          saved = current
          Git.run("git", "checkout", base, dir: @dir)
          Git.run("git", "pull", "origin", base, dir: @dir)
          Git.run("git", "checkout", saved, dir: @dir)
          spinner.update_title("Pulled #{base}")
        end

        # Restack
        restack = Commands::Restack.new([], dir: @dir)
        ordered = stack.ordered_stack(current)

        if ordered.nil? || ordered.empty?
          puts ::CLI::UI.fmt("{{green:✓}} Synced #{base}. No stack to restack.")
          return
        end

        restack.restack_ordered(ordered)

        target = ordered.include?(current) ? current : ordered.last
        Git.run("git", "checkout", target, dir: @dir)

        puts ::CLI::UI.fmt("{{green:✓}} Synced and restacked. On {{bold:#{target}}}")
      end

      private

      def find_base(branch, stack)
        # Walk up to the top-level parent (the one with no gt-parent)
        ordered = stack.ordered_stack(branch)
        if ordered
          root   = ordered.first
          Git.parent_of(root, dir: @dir) # should be main or similar
        else
          # If not in a stack, try the current branch's configured parent or "main"
          Git.parent_of(branch, dir: @dir) || default_base
        end
      end

      def default_base
        # Try common base branch names
        %w[main master].each do |name|
          out, ok = Git.run_safe("git", "rev-parse", "--verify", name, dir: @dir)
          return name if ok
        end
        nil
      end
    end
  end
end
