require_relative "test_helper"
require_relative "git_sandbox"

class ScaffoldTest < Minitest::Test
  def test_version_defined
    assert_kind_of String, GT::VERSION
    refute_empty GT::VERSION
  end

  def test_cli_unknown_command_exits
    assert_raises(SystemExit) do
      GT::CLI.start(["nonexistent-command"])
    end
  end

  def test_cli_valid_command_dispatches
    # create with no name exits 1 — verifies dispatch reaches the command
    assert_raises(SystemExit) do
      GT::CLI.start(["create"])
    end
  end
end

class GitHelperTest < Minitest::Test
  include GitSandbox

  def test_current_branch
    assert_equal "main", GT::Git.current_branch
  end

  def test_current_branch_nil_outside_git_repo
    Dir.chdir(@tmpdir) do
      assert_nil GT::Git.current_branch
    end
  end

  def test_tip_sha
    sha = GT::Git.tip_sha("main")
    assert_match(/\A[0-9a-f]{40}\z/, sha)
  end

  def test_tip_sha_nil_for_invalid_ref
    assert_nil GT::Git.tip_sha("nonexistent-branch-xyz-12345")
  end

  def test_gt_parent_nil_when_not_set
    assert_nil GT::Git.gt_parent("main")
  end

  def test_set_and_get_gt_parent
    GT::Git.set_gt_parent("main", "root")
    assert_equal "root", GT::Git.gt_parent("main")
  ensure
    system("git", "config", "--unset", "branch.main.gt-parent", [:out, :err] => File::NULL)
  end

  def test_gt_fork_point_nil_when_not_set
    assert_nil GT::Git.gt_fork_point("main")
  end

  def test_set_and_get_gt_fork_point
    sha = "abc123def456abc123def456abc123def456abc1"
    GT::Git.set_gt_fork_point("main", sha)
    assert_equal sha, GT::Git.gt_fork_point("main")
  ensure
    system("git", "config", "--unset", "branch.main.gt-fork-point", [:out, :err] => File::NULL)
  end

  def test_all_gt_branches_empty_when_none
    assert_equal({}, GT::Git.all_gt_branches)
  end

  def test_all_gt_branches_returns_mapping
    make_gt_branch("feature-a", "main")
    result = GT::Git.all_gt_branches
    assert_equal "main", result["feature-a"]
  end

  def test_stack_for_nil_when_no_gt_branches
    assert_nil GT::Git.stack_for("main")
  end

  def test_stack_for_single_branch
    make_gt_branch("feature-a", "main")
    stack = GT::Git.stack_for("feature-a")
    assert_equal ["feature-a"], stack
  end

  def test_stack_for_two_branches
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "commit on A")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    make_gt_branch("feature-b", "feature-a")
    make_commit("b.txt", "b", "commit on B")

    stack = GT::Git.stack_for("feature-b")
    assert_equal ["feature-a", "feature-b"], stack
  end
end
