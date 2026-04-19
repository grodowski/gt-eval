# frozen_string_literal: true

module GT
  module Stack
    module_function

    # Find the root of the stack (first gt-managed branch above main).
    def root
      all = managed_branches
      return nil if all.empty?

      # Walk from any managed branch up to find root (whose parent is main/unmanaged)
      all.each do |b|
        parent = Git.gt_parent(b)
        return b unless all.include?(parent)
      end
      all.first
    end

    # Return the ordered stack as an array of branch names from root to tip.
    def ordered
      all = managed_branches
      return [] if all.empty?

      # Build parent -> child mapping
      children = {}
      all.each do |b|
        parent = Git.gt_parent(b)
        children[parent] = b
      end

      # Start from root and walk down
      r = root
      return [] unless r

      chain = [r]
      current = r
      while (child = children[current])
        chain << child
        current = child
      end
      chain
    end

    # All branches that have gt-parent set.
    def managed_branches
      out, ok = Git.run_safe("config", "--local", "--get-regexp", "^branch\\..*\\.gt-parent$")
      return [] unless ok

      out.lines.filter_map do |line|
        # Format: branch.<name>.gt-parent <value>
        if line =~ /^branch\.(.+)\.gt-parent\s/
          $1
        end
      end
    end

    # Find children of a given branch.
    def children_of(branch)
      managed_branches.select { |b| Git.gt_parent(b) == branch }
    end
  end
end
