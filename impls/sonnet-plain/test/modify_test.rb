# frozen_string_literal: true

require_relative "test_helper"

class ModifyTest < Minitest::Test
  include GitSandbox

  def test_modify_amends_head_commit
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      original_sha = commit_sha(local_dir)

      # Make a change and modify
      File.write(File.join(local_dir, "a.txt"), "a modified\n")
      gt(local_dir, "modify")

      new_sha = commit_sha(local_dir)
      refute_equal original_sha, new_sha
    end
  end

  def test_modify_with_message_changes_commit_message
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      gt(local_dir, "modify", "-m", "A revised")

      msg = git!(local_dir, "git", "log", "--pretty=%s", "-1")
      assert_equal "A revised", msg
    end
  end

  def test_modify_force_pushes_current_branch
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      original_remote_sha = git!(local_dir, "git", "rev-parse", "origin/feature-a")

      File.write(File.join(local_dir, "a.txt"), "modified\n")
      gt(local_dir, "modify")

      new_remote_sha = git!(local_dir, "git", "rev-parse", "origin/feature-a")
      refute_equal original_remote_sha, new_remote_sha
    end
  end

  def test_modify_restacks_children
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      File.write(File.join(local_dir, "b.txt"), "b\n")
      git!(local_dir, "git", "add", "b.txt")
      gt(local_dir, "create", "feature-b", "-m", "B")

      # Go back to feature-a and modify it
      git!(local_dir, "git", "checkout", "feature-a")
      File.write(File.join(local_dir, "a.txt"), "a modified\n")
      gt(local_dir, "modify")

      # Should end on the tip (feature-b)
      assert_equal "feature-b", current_branch(local_dir)

      # feature-b should be rebased onto the new feature-a tip
      feature_a_tip    = git!(local_dir, "git", "rev-parse", "feature-a")
      feature_b_parent = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feature-b")
      assert_equal feature_a_tip, feature_b_parent
    end
  end

  def test_modify_alias_m
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      original_sha = commit_sha(local_dir)
      File.write(File.join(local_dir, "a.txt"), "changed\n")
      gt(local_dir, "m")

      assert_equal "feature-a", current_branch(local_dir)
      refute_equal original_sha, commit_sha(local_dir)
    end
  end

  def test_modify_ends_on_tip_of_stack
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      File.write(File.join(local_dir, "b.txt"), "b\n")
      git!(local_dir, "git", "add", "b.txt")
      gt(local_dir, "create", "feature-b", "-m", "B")

      File.write(File.join(local_dir, "c.txt"), "c\n")
      git!(local_dir, "git", "add", "c.txt")
      gt(local_dir, "create", "feature-c", "-m", "C")

      # Modify from the middle of the stack
      git!(local_dir, "git", "checkout", "feature-b")
      File.write(File.join(local_dir, "b.txt"), "b modified\n")
      gt(local_dir, "modify")

      # Should end on tip (feature-c)
      assert_equal "feature-c", current_branch(local_dir)
    end
  end
end
