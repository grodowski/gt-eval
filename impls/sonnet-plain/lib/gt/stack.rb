# frozen_string_literal: true

module GT
  class Stack
    attr_reader :dir

    def initialize(dir: nil)
      @dir = dir
    end

    # Return all branches that have a gt-parent set
    def managed_branches
      Git.all_branches(dir: dir).select do |b|
        Git.parent_of(b, dir: dir)
      end
    end

    # Return ordered stack starting from root, ending at tip, containing `branch`
    # Returns nil if branch is not in a gt-managed stack
    def ordered_stack(branch)
      # Build child map
      children = {}
      managed_branches.each do |b|
        parent = Git.parent_of(b, dir: dir)
        children[parent] ||= []
        children[parent] << b
      end

      # Find the root of the stack containing `branch`
      root = find_root(branch)
      return nil unless root

      # Walk from root to tip (linear only)
      walk_linear(root, children)
    end

    # Returns [stack_array, index_of_branch] or nil
    def locate(branch)
      stack = ordered_stack(branch)
      return nil unless stack
      idx = stack.index(branch)
      return nil unless idx
      [stack, idx]
    end

    # Children of a branch in the current stack
    def children_of(branch)
      managed_branches.select do |b|
        Git.parent_of(b, dir: dir) == branch
      end
    end

    private

    def find_root(branch)
      current = branch
      visited = []
      loop do
        return nil if visited.include?(current)
        visited << current
        parent = Git.parent_of(current, dir: dir)
        # Branch has no gt-parent → it is a base branch (e.g. main), not managed
        return nil if parent.nil?
        # If parent has no gt-parent, parent is the base; current is the stack root
        parent_gt_parent = Git.parent_of(parent, dir: dir)
        return current if parent_gt_parent.nil?
        # Walk up
        current = parent
      end
    end

    def walk_linear(branch, children)
      result = [branch]
      loop do
        kids = children[branch] || []
        break if kids.empty?
        # For linear stacks, take first child
        branch = kids.first
        result << branch
      end
      result
    end
  end
end
