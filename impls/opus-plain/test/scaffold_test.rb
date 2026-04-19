# frozen_string_literal: true

require_relative "test_helper"

class ScaffoldTest < Minitest::Test
  include GitSandbox

  def test_git_current_branch
    assert_equal "main", GT::Git.current_branch
  end

  def test_git_run_safe
    _out, ok = GT::Git.run_safe("status")
    assert ok
  end

  def test_managed_branches_empty
    assert_equal [], GT::Stack.managed_branches
  end

  def test_version
    refute_nil GT::VERSION
  end
end
