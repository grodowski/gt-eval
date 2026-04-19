# frozen_string_literal: true

module GT
  class Stack
    def self.find_root(branch)
      current = branch
      loop do
        parent = Git.parent_of(current)
        return current unless parent && Git.parent_of(parent)

        current = parent
      end
    end

    def self.children_of(branch)
      out, ok = Git.run_safe("config", "--get-regexp", "^branch\\..*\\.gt-parent$")
      return [] unless ok

      results = []
      out.each_line do |line|
        key, value = line.strip.split(" ", 2)
        next unless value == branch

        # Extract branch name from key: branch.<name>.gt-parent
        name = key.sub("branch.", "").sub(".gt-parent", "")
        results << name
      end
      results
    end

    def self.ordered_stack(root)
      result = [root]
      current = root
      loop do
        children = children_of(current)
        break if children.empty?

        child = children.first
        result << child
        current = child
      end
      result
    end

    def self.full_stack_from(branch)
      root = find_root(branch)
      ordered_stack(root)
    end

    def self.all_gt_branches
      out, ok = Git.run_safe("config", "--get-regexp", "^branch\\..*\\.gt-parent$")
      return [] unless ok

      out.each_line.map do |line|
        key, = line.strip.split(" ", 2)
        key.sub("branch.", "").sub(".gt-parent", "")
      end
    end
  end
end
