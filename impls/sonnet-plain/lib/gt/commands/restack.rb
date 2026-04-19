# frozen_string_literal: true

module GT
  module Commands
    class Restack
      def initialize(argv, dir: nil)
        @dir = dir
      end

      def run
        current = Git.current_branch(dir: @dir)
        stack   = Stack.new(dir: @dir)

        ordered = stack.ordered_stack(current)

        if ordered.nil? || ordered.empty?
          $stderr.puts ::CLI::UI.fmt("{{red:No gt-managed stack found. Use gt create to start a stack.}}")
          exit 1
        end

        restack_ordered(ordered)
        update_pr_descriptions(ordered)

        # Return to original branch (or tip if it was removed)
        target = ordered.include?(current) ? current : ordered.last
        Git.run("git", "checkout", target, dir: @dir)

        puts ::CLI::UI.fmt("{{green:✓}} Restack complete. On {{bold:#{target}}}")
      end

      # Exposed for use by other commands (modify, sync)
      def restack_ordered(ordered)
        ordered.each do |branch|
          parent     = Git.parent_of(branch, dir: @dir)
          fork_point = Git.fork_point_of(branch, dir: @dir)

          next unless parent && fork_point

          parent_tip = Git.commit_sha(parent, dir: @dir)

          # Skip if already up to date
          if fork_point == parent_tip
            puts ::CLI::UI.fmt("  {{dim:#{branch} is up to date}}")
            next
          end

          ::CLI::UI::Spinner.spin("Rebasing #{branch} onto #{parent}") do |spinner|
            _out, err, status = Open3.capture3(
              "git", "rebase", "--onto", parent, fork_point, branch,
              chdir: @dir || Dir.pwd
            )
            if status.success?
              # Update fork-point to new parent tip
              Git.config_set("branch.#{branch}.gt-fork-point", parent_tip, dir: @dir)
              spinner.update_title("Rebased #{branch} onto #{parent}")
            else
              # Abort rebase and raise
              Open3.capture3("git", "rebase", "--abort", chdir: @dir || Dir.pwd)
              raise GT::Git::Error, "Rebase of #{branch} failed:\n#{err.strip}"
            end
          end

          # Force push
          if Git.remote_exists?("origin", dir: @dir)
            ::CLI::UI::Spinner.spin("Force-pushing #{branch}") do |spinner|
              Git.run("git", "push", "--force-with-lease", "origin", branch, dir: @dir)
              spinner.update_title("Force-pushed #{branch}")
            end
          end
        end
      end

      private

      def update_pr_descriptions(ordered)
        gh_path, = Open3.capture3("which", "gh")
        return if gh_path.strip.empty?

        stack_comment = build_stack_comment(ordered)
        ordered.each do |branch|
          update_pr_body(branch, stack_comment)
        end
      rescue StandardError
        # Degrade gracefully
      end

      def build_stack_comment(ordered)
        lines = ["<!-- gt-stack-begin -->", "## Stack"]
        ordered.each_with_index do |branch, idx|
          marker = idx == ordered.length - 1 ? "➡" : " "
          lines << "#{marker} `#{branch}`"
        end
        lines << "<!-- gt-stack-end -->"
        lines.join("\n")
      end

      def update_pr_body(branch, stack_comment)
        _out, err, status = Open3.capture3(
          "gh", "pr", "view", branch, "--json", "body", "--jq", ".body",
          chdir: @dir || Dir.pwd
        )
        return unless status.success?

        current_body = _out.strip

        new_body = if current_body.include?("<!-- gt-stack-begin -->")
                     current_body.sub(
                       /<!-- gt-stack-begin -->.*<!-- gt-stack-end -->/m,
                       stack_comment
                     )
                   else
                     "#{current_body}\n\n#{stack_comment}"
                   end

        Open3.capture3(
          "gh", "pr", "edit", branch, "--body", new_body,
          chdir: @dir || Dir.pwd
        )
      rescue StandardError
        # ignore
      end
    end
  end
end
