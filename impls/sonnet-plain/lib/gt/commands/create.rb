# frozen_string_literal: true

module GT
  module Commands
    class Create
      def initialize(argv, dir: nil)
        @dir     = dir
        @name    = nil
        @message = nil
        parse!(argv)
      end

      def run
        unless @name && !@name.empty?
          abort "Usage: gt create <name> [-m <message>]"
        end

        parent  = Git.current_branch(dir: @dir)
        fork_pt = Git.commit_sha("HEAD", dir: @dir)

        # Create and switch to new branch FIRST, so the commit lands on it
        ::CLI::UI::Spinner.spin("Creating branch #{@name}") do |spinner|
          Git.run("git", "checkout", "-b", @name, dir: @dir)
          spinner.update_title("Created branch #{@name}")
        end

        # Record parent metadata (fork_pt is the parent tip before any commits)
        Git.set_parent(@name, parent, fork_pt, dir: @dir)

        # Stage tracked files
        ::CLI::UI::Spinner.spin("Staging tracked files") do |spinner|
          Git.run("git", "add", "-u", dir: @dir)
          spinner.update_title("Staged tracked files")
        end

        # Always commit (allow-empty ensures a commit even with nothing staged)
        commit_msg = @message || @name
        ::CLI::UI::Spinner.spin("Committing") do |spinner|
          Git.run("git", "commit", "--allow-empty", "-m", commit_msg, dir: @dir)
          spinner.update_title("Committed: #{commit_msg}")
        end

        # Push
        if Git.remote_exists?("origin", dir: @dir)
          ::CLI::UI::Spinner.spin("Pushing #{@name}") do |spinner|
            Git.run("git", "push", "-u", "origin", @name, dir: @dir)
            spinner.update_title("Pushed #{@name}")
          end

          # Open PR if gh is available
          open_pr(parent)
        else
          puts ::CLI::UI.fmt("{{yellow:No remote 'origin' found, skipping push/PR}}")
        end

        puts ::CLI::UI.fmt("{{green:✓}} Created branch {{bold:#{@name}}} off {{bold:#{parent}}}")
      end

      private

      def parse!(argv)
        argv = argv.dup
        @name = argv.shift
        while (arg = argv.shift)
          case arg
          when "-m", "--message"
            @message = argv.shift
          end
        end
      end

      def open_pr(parent)
        gh_path, = Open3.capture3("which", "gh")
        return if gh_path.strip.empty?

        ::CLI::UI::Spinner.spin("Opening PR") do |spinner|
          title = @message || @name
          _out, err, status = Open3.capture3(
            "gh", "pr", "create",
            "--title", title,
            "--body", "",
            "--base", parent,
            "--head", @name,
            chdir: @dir || Dir.pwd
          )
          if status.success?
            spinner.update_title("PR opened targeting #{parent}")
          else
            spinner.update_title("PR skipped: #{err.strip}")
          end
        end
      rescue StandardError => e
        puts ::CLI::UI.fmt("{{yellow:PR creation skipped: #{e.message}}}")
      end
    end
  end
end
