# frozen_string_literal: true

require_relative "test_helper"

class ScaffoldTest < Minitest::Test
  include GitSandbox

  def test_sandbox_setup
    with_sandbox do |local_dir, _remote_dir|
      branch = git!(local_dir, "git", "rev-parse", "--abbrev-ref", "HEAD")
      assert_equal "main", branch
      assert File.exist?(File.join(local_dir, "README.md"))
    end
  end

  def test_gem_loads
    assert_equal "0.1.0", GT::VERSION
  end
end
