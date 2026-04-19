# frozen_string_literal: true

module GT
  module Git
    class Error < StandardError; end

    # Run a git command, returning stdout. Raises on failure.
    def self.run(*args, dir: nil, input: nil)
      opts = {}
      opts[:chdir] = dir if dir
      stdout, stderr, status = Open3.capture3(*args, **opts)
      unless status.success?
        raise Error, "Command failed: #{args.join(" ")}\n#{stderr.strip}"
      end
      stdout.strip
    end

    # Run a git command, returning [stdout, success?]
    def self.run_safe(*args, dir: nil)
      opts = {}
      opts[:chdir] = dir if dir
      stdout, _stderr, status = Open3.capture3(*args, **opts)
      [stdout.strip, status.success?]
    end

    def self.current_branch(dir: nil)
      run("git", "rev-parse", "--abbrev-ref", "HEAD", dir: dir)
    end

    def self.commit_sha(ref = "HEAD", dir: nil)
      run("git", "rev-parse", ref, dir: dir)
    end

    def self.config_get(key, dir: nil)
      out, ok = run_safe("git", "config", "--local", key, dir: dir)
      ok ? out : nil
    end

    def self.config_set(key, value, dir: nil)
      run("git", "config", "--local", key, value, dir: dir)
    end

    def self.config_unset(key, dir: nil)
      run_safe("git", "config", "--local", "--unset", key, dir: dir)
    end

    def self.all_branches(dir: nil)
      out = run("git", "branch", "--format=%(refname:short)", dir: dir)
      out.split("\n").map(&:strip).reject(&:empty?)
    end

    def self.parent_of(branch, dir: nil)
      config_get("branch.#{branch}.gt-parent", dir: dir)
    end

    def self.fork_point_of(branch, dir: nil)
      config_get("branch.#{branch}.gt-fork-point", dir: dir)
    end

    def self.set_parent(branch, parent, fork_point, dir: nil)
      config_set("branch.#{branch}.gt-parent", parent, dir: dir)
      config_set("branch.#{branch}.gt-fork-point", fork_point, dir: dir)
    end

    def self.merge_base(a, b, dir: nil)
      run("git", "merge-base", a, b, dir: dir)
    end

    def self.remote_exists?(remote = "origin", dir: nil)
      _, ok = run_safe("git", "remote", "get-url", remote, dir: dir)
      ok
    end
  end
end
