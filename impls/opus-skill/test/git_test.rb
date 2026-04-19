# frozen_string_literal: true

require_relative "test_helper"

class GitTest < GTTest
  def test_current_branch
    assert_equal "main", GT::Git.current_branch
  end

  def test_main_branch
    assert_equal "main", GT::Git.main_branch
  end

  def test_set_and_get_config
    GT::Git.set_config("test.key", "value")
    assert_equal "value", GT::Git.get_config("test.key")
  end

  def test_get_config_missing_key
    assert_nil GT::Git.get_config("nonexistent.key")
  end

  def test_parent_and_fork_point
    sandbox.run_git("checkout", "-b", "child")
    GT::Git.set_parent("child", "main")
    GT::Git.set_fork_point("child", "abc123")

    assert_equal "main", GT::Git.parent_of("child")
    assert_equal "abc123", GT::Git.fork_point_of("child")
  end

  def test_rev_parse
    sha = GT::Git.rev_parse("HEAD")
    assert_match(/\A[0-9a-f]{40}\z/, sha)
  end

  def test_branch_exists
    assert GT::Git.branch_exists?("main")
    refute GT::Git.branch_exists?("nonexistent-branch")
  end

  def test_run_failure_raises
    assert_raises(RuntimeError) do
      GT::Git.run("checkout", "nonexistent-branch-xyz")
    end
  end

  def test_run_safe_returns_success_status
    out, ok = GT::Git.run_safe("rev-parse", "HEAD")
    assert ok
    refute_empty out
  end

  def test_run_safe_returns_failure_status
    _out, ok = GT::Git.run_safe("rev-parse", "--verify", "nonexistent")
    refute ok
  end

  def test_gh_available
    # gh may or may not be available in test env, just ensure it returns boolean
    result = GT::Git.gh_available?
    assert_includes [true, false], result
  end

  def test_gh_available_when_not_installed
    # Simulate gh not found by temporarily overriding PATH
    old_path = ENV["PATH"]
    ENV["PATH"] = ""
    refute GT::Git.gh_available?
  ensure
    ENV["PATH"] = old_path
  end

  def test_gh_returns_nil_when_not_available
    old_path = ENV["PATH"]
    ENV["PATH"] = ""
    assert_nil GT::Git.gh("version")
  ensure
    ENV["PATH"] = old_path
  end

  def test_gh_success
    skip "gh not available" unless GT::Git.gh_available?
    result = GT::Git.gh("version")
    assert_match(/gh version/, result)
  end
end
