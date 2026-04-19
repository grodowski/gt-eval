# frozen_string_literal: true

require_relative "test_helper"

class RestackTest < Minitest::Test
  include GitSandbox

  # Build a 2-branch stack: main → A → B
  def setup_stack(local_dir)
    File.write(File.join(local_dir, "a.txt"), "a\n")
    git!(local_dir, "git", "add", "a.txt")
    gt(local_dir, "create", "feature-a", "-m", "A")

    File.write(File.join(local_dir, "b.txt"), "b\n")
    git!(local_dir, "git", "add", "b.txt")
    gt(local_dir, "create", "feature-b", "-m", "B")
    # Now on feature-b
  end

  def test_restack_no_stack_exits_1
    with_sandbox do |local_dir, _remote_dir|
      # On main, no gt branches
      assert_raises(SystemExit) { gt(local_dir, "restack") }
    end
  end

  def test_restack_up_to_date_is_noop
    with_sandbox do |local_dir, _remote_dir|
      setup_stack(local_dir)
      # Stack is already up to date, restack should succeed without rebasing
      gt(local_dir, "restack")
      assert_equal "feature-b", current_branch(local_dir)
    end
  end

  def test_restack_rebases_child_onto_updated_parent
    with_sandbox do |local_dir, remote_dir|
      setup_stack(local_dir)

      # Simulate parent (feature-a) getting a new commit after feature-b was created
      git!(local_dir, "git", "checkout", "feature-a")
      File.write(File.join(local_dir, "a2.txt"), "a2\n")
      git!(local_dir, "git", "add", "a2.txt")
      git!(local_dir, "git", "commit", "-m", "A2")
      git!(local_dir, "git", "push", "--force-with-lease", "origin", "feature-a")

      # Go to feature-b and restack
      git!(local_dir, "git", "checkout", "feature-b")
      gt(local_dir, "restack")

      # feature-b should now be based on updated feature-a
      feature_a_tip = commit_sha(local_dir, "feature-a")
      feature_b_parent = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feature-b")
      assert_equal feature_a_tip, feature_b_parent
    end
  end

  def test_restack_updates_fork_point
    with_sandbox do |local_dir, _remote_dir|
      setup_stack(local_dir)

      git!(local_dir, "git", "checkout", "feature-a")
      File.write(File.join(local_dir, "a2.txt"), "a2\n")
      git!(local_dir, "git", "add", "a2.txt")
      git!(local_dir, "git", "commit", "-m", "A2")
      git!(local_dir, "git", "push", "--force-with-lease", "origin", "feature-a")

      git!(local_dir, "git", "checkout", "feature-b")
      gt(local_dir, "restack")

      new_fork_point = GT::Git.config_get("branch.feature-b.gt-fork-point", dir: local_dir)
      feature_a_tip  = commit_sha(local_dir, "feature-a")
      assert_equal feature_a_tip, new_fork_point
    end
  end

  def test_restack_from_any_branch_restacks_whole_stack
    with_sandbox do |local_dir, _remote_dir|
      setup_stack(local_dir)

      # Add commit to feature-a (the parent)
      git!(local_dir, "git", "checkout", "feature-a")
      File.write(File.join(local_dir, "a2.txt"), "a2\n")
      git!(local_dir, "git", "add", "a2.txt")
      git!(local_dir, "git", "commit", "-m", "A2")
      git!(local_dir, "git", "push", "--force-with-lease", "origin", "feature-a")

      # Restack from feature-a (not feature-b)
      gt(local_dir, "restack")

      # feature-b should be rebased
      feature_a_tip    = commit_sha(local_dir, "feature-a")
      feature_b_parent = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feature-b")
      assert_equal feature_a_tip, feature_b_parent
    end
  end

  def test_restack_three_deep
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feat-a", "-m", "A")

      File.write(File.join(local_dir, "b.txt"), "b\n")
      git!(local_dir, "git", "add", "b.txt")
      gt(local_dir, "create", "feat-b", "-m", "B")

      File.write(File.join(local_dir, "c.txt"), "c\n")
      git!(local_dir, "git", "add", "c.txt")
      gt(local_dir, "create", "feat-c", "-m", "C")

      # Add commit to feat-a
      git!(local_dir, "git", "checkout", "feat-a")
      File.write(File.join(local_dir, "a2.txt"), "a2\n")
      git!(local_dir, "git", "add", "a2.txt")
      git!(local_dir, "git", "commit", "-m", "A2")
      git!(local_dir, "git", "push", "--force-with-lease", "origin", "feat-a")

      git!(local_dir, "git", "checkout", "feat-c")
      gt(local_dir, "restack")

      # feat-b parent should be feat-a tip
      feat_a_tip    = commit_sha(local_dir, "feat-a")
      feat_b_parent = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feat-b")
      assert_equal feat_a_tip, feat_b_parent

      # feat-c parent should be feat-b tip
      feat_b_tip    = commit_sha(local_dir, "feat-b")
      feat_c_parent = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feat-c")
      assert_equal feat_b_tip, feat_c_parent
    end
  end
end
