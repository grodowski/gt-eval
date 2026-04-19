# frozen_string_literal: true

module GT
  module Commands
    module Create
      module_function

      def run(args)
        name = nil
        message = nil

        i = 0
        while i < args.length
          case args[i]
          when "-m"
            message = args[i + 1]
            i += 2
          else
            name = args[i]
            i += 1
          end
        end

        unless name
          $stderr.puts "Usage: gt create <name> [-m <msg>]"
          exit 1
        end

        parent = Git.current_branch
        parent_sha = Git.rev_parse("HEAD")

        # Create and switch to new branch FIRST so commits land here, not on parent
        Git.run("checkout", "-b", name)

        # Stage tracked files and commit on the new branch
        Git.run("add", "-u")

        message ||= name
        begin
          Git.run("commit", "-m", message)
        rescue RuntimeError
          # Nothing to commit is fine — we'll still create the branch
        end

        # Record stack metadata
        Git.set_parent(name, parent)
        Git.set_fork_point(name, parent_sha)

        # Push
        begin
          Git.run("push", "-u", "origin", name)
        rescue RuntimeError => e
          $stderr.puts "Warning: push failed: #{e.message}"
        end

        # Open PR targeting parent
        begin
          Git.gh("pr", "create", "--base", parent, "--head", name, "--title", message, "--body", "")
        rescue RuntimeError => e
          $stderr.puts "Warning: PR creation failed: #{e.message}"
        end

        puts "Created branch #{name} on top of #{parent}"
      end
    end
  end
end
