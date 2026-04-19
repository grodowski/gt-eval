# frozen_string_literal: true

require "open3"

module GT
  module Git
    class Error < StandardError; end

    module_function

    # Run a git command. Returns stdout on success, raises Git::Error on failure.
    def run(*args)
      out, err, status = Open3.capture3("git", *args)
      raise Error, "git #{args.first}: #{err.strip}" unless status.success?

      out.strip
    end

    # Run a git command, returning [stdout, success?]
    def run_safe(*args)
      out, _err, status = Open3.capture3("git", *args)
      [out.strip, status.success?]
    end

    def current_branch
      run("rev-parse", "--abbrev-ref", "HEAD")
    end

    def main_branch
      # Try common main branch names
      %w[main master].each do |name|
        _out, ok = run_safe("rev-parse", "--verify", name)
        return name if ok
      end
      "main"
    end

    def branch_exists?(name)
      _out, ok = run_safe("rev-parse", "--verify", name)
      ok
    end

    def rev_parse(ref)
      run("rev-parse", ref)
    end

    def config_get(key)
      out, ok = run_safe("config", "--local", key)
      ok ? out : nil
    end

    def config_set(key, value)
      run("config", "--local", key, value)
    end

    def gt_parent(branch)
      config_get("branch.#{branch}.gt-parent")
    end

    def gt_fork_point(branch)
      config_get("branch.#{branch}.gt-fork-point")
    end

    def set_gt_parent(branch, parent)
      config_set("branch.#{branch}.gt-parent", parent)
    end

    def set_gt_fork_point(branch, sha)
      config_set("branch.#{branch}.gt-fork-point", sha)
    end
  end
end
