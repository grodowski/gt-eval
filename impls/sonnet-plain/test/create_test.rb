# frozen_string_literal: true

require_relative "test_helper"

class CreateTest < Minitest::Test
  include GitSandbox

  def test_create_branch_from_main
    with_sandbox do |local_dir, _remote_dir|
      # Add a tracked file change
      File.write(File.join(local_dir, "README.md"), "hello\nworld\n")

      gt(local_dir, "create", "feature-a", "-m", "Add feature A")

      assert_equal "feature-a", current_branch(local_dir)
    end
  end

  def test_create_records_gt_parent
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "README.md"), "change\n")

      gt(local_dir, "create", "feature-a", "-m", "Add feature A")

      parent = GT::Git.config_get("branch.feature-a.gt-parent", dir: local_dir)
      assert_equal "main", parent
    end
  end

  def test_create_records_gt_fork_point
    with_sandbox do |local_dir, _remote_dir|
      main_sha = commit_sha(local_dir)
      File.write(File.join(local_dir, "README.md"), "change\n")

      gt(local_dir, "create", "feature-a", "-m", "Add feature A")

      fork_pt = GT::Git.config_get("branch.feature-a.gt-fork-point", dir: local_dir)
      assert_equal main_sha, fork_pt
    end
  end

  def test_create_stacked_branch
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "README.md"), "change A\n")
      gt(local_dir, "create", "feature-a", "-m", "A")

      File.write(File.join(local_dir, "file_b.txt"), "change B\n")
      git!(local_dir, "git", "add", "file_b.txt")
      gt(local_dir, "create", "feature-b", "-m", "B")

      assert_equal "feature-b", current_branch(local_dir)
      parent = GT::Git.config_get("branch.feature-b.gt-parent", dir: local_dir)
      assert_equal "feature-a", parent
    end
  end

  def test_create_pushes_to_remote
    with_sandbox do |local_dir, remote_dir|
      File.write(File.join(local_dir, "README.md"), "pushed\n")
      gt(local_dir, "create", "feature-a", "-m", "pushed")

      # Check remote has the branch
      out = Open3.capture3("git", "branch", chdir: remote_dir).first
      assert_includes out, "feature-a"
    end
  end

  def test_create_requires_name
    with_sandbox do |local_dir, _remote_dir|
      assert_raises(SystemExit) do
        gt(local_dir, "create")
      end
    end
  end

  def test_create_without_staged_changes_still_creates_branch
    with_sandbox do |local_dir, _remote_dir|
      # No changes to stage
      gt(local_dir, "create", "feature-empty", "-m", "empty")
      assert_equal "feature-empty", current_branch(local_dir)
      parent = GT::Git.config_get("branch.feature-empty.gt-parent", dir: local_dir)
      assert_equal "main", parent
    end
  end
end
