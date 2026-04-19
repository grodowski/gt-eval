# frozen_string_literal: true

require "open3"

module GT
  module Git
    module_function

    def run(*args)
      out, err, status = Open3.capture3("git", *args)
      raise "git #{args.join(' ')} failed: #{err}" unless status.success?

      out.chomp
    end

    def run_safe(*args)
      out, _err, status = Open3.capture3("git", *args)
      [out.chomp, status.success?]
    end

    def current_branch
      run("rev-parse", "--abbrev-ref", "HEAD")
    end

    def main_branch
      "main"
    end

    def set_config(key, value)
      run("config", key, value)
    end

    def get_config(key)
      out, ok = run_safe("config", "--get", key)
      ok ? out : nil
    end

    def parent_of(branch)
      get_config("branch.#{branch}.gt-parent")
    end

    def fork_point_of(branch)
      get_config("branch.#{branch}.gt-fork-point")
    end

    def set_parent(branch, parent)
      set_config("branch.#{branch}.gt-parent", parent)
    end

    def set_fork_point(branch, sha)
      set_config("branch.#{branch}.gt-fork-point", sha)
    end

    def rev_parse(ref)
      run("rev-parse", ref)
    end

    def branch_exists?(name)
      _, ok = run_safe("rev-parse", "--verify", name)
      ok
    end

    def gh_available?
      _, _, status = Open3.capture3("gh", "version")
      status.success?
    rescue Errno::ENOENT
      false
    end

    def gh(*args)
      return nil unless gh_available?

      out, err, status = Open3.capture3("gh", *args)
      raise "gh #{args.join(' ')} failed: #{err}" unless status.success?

      out.chomp
    end
  end
end
