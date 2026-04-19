require "open3"

module GT
  module Git
    def self.run(*cmd)
      out, err, status = Open3.capture3(*cmd)
      [out.strip, err.strip, status]
    end

    def self.current_branch
      out, _err, status = run("git", "rev-parse", "--abbrev-ref", "HEAD")
      status.success? ? out : nil
    end

    def self.tip_sha(branch)
      out, _err, status = run("git", "rev-parse", branch)
      status.success? ? out : nil
    end

    def self.gt_parent(branch)
      out, _err, status = run("git", "config", "--get", "branch.#{branch}.gt-parent")
      status.success? ? out : nil
    end

    def self.gt_fork_point(branch)
      out, _err, status = run("git", "config", "--get", "branch.#{branch}.gt-fork-point")
      status.success? ? out : nil
    end

    def self.set_gt_parent(branch, parent)
      run("git", "config", "branch.#{branch}.gt-parent", parent)
    end

    def self.set_gt_fork_point(branch, sha)
      run("git", "config", "branch.#{branch}.gt-fork-point", sha)
    end

    # Returns a hash of branch => gt-parent for all branches with gt-parent set
    def self.all_gt_branches
      out, _err, status = run("git", "config", "--get-regexp", "branch\\..*\\.gt-parent")
      return {} unless status.success?

      out.scan(/^branch\.(.+)\.gt-parent (.+)$/).to_h
    end

    # Find the ordered stack (root-first) containing the given branch.
    # Only includes gt-managed branches (those with a gt-parent set).
    # Returns an array of branch names, or nil if branch is not gt-managed.
    def self.stack_for(branch)
      all = all_gt_branches
      return nil if all.empty?

      # Walk up to find the root gt-managed branch in the chain
      node    = branch
      visited = []
      while node && !visited.include?(node)
        visited << node
        parent = all[node]
        break if parent.nil? || !all.key?(parent)
        node = parent
      end
      # node must itself be gt-managed; if not, branch is outside the stack
      return nil unless all.key?(node)

      root = node

      # Walk down from root, only following gt-managed branches
      chain = []
      cur   = root
      while cur && all.key?(cur)
        chain << cur
        child = all.key(cur)
        break if child.nil? || chain.include?(child)
        cur = child
      end
      chain
    end
  end
end
