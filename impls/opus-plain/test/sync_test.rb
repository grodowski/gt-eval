# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gt/commands/sync"

class SyncTest < Minitest::Test
  include GitSandbox

  def test_sync_pulls_main_and_restacks
    # Create stack directly off initial main (no extra main commits)
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")
    GT::Git.run("push", "-u", "origin", "branch-a")

    # Simulate a new commit on remote main via another clone
    other_dir = File.join(@sandbox_dir, "other")
    system("git", "clone", @remote_dir, other_dir, out: File::NULL, err: File::NULL)
    Dir.chdir(other_dir)
    system("git", "config", "user.email", "other@test.com", out: File::NULL, err: File::NULL)
    system("git", "config", "user.name", "Other", out: File::NULL, err: File::NULL)
    File.write("remote_change.txt", "from remote\n")
    system("git", "add", "remote_change.txt", out: File::NULL, err: File::NULL)
    system("git", "commit", "-m", "remote commit on main", out: File::NULL, err: File::NULL)
    system("git", "push", "origin", "main", out: File::NULL, err: File::NULL)

    Dir.chdir(@local_dir)

    GT::GH.stub(:available?, false) do
      GT::Commands::Sync.new([]).run
    end

    # Main should have the remote commit
    GT::Git.run("checkout", "main")
    log = GT::Git.run("log", "--oneline")
    assert_includes log, "remote commit on main"

    # branch-a should be rebased on top of updated main
    GT::Git.run("checkout", "branch-a")
    log = GT::Git.run("log", "--oneline")
    assert_includes log, "remote commit on main"
    assert_includes log, "on a"
  end

  def test_sync_with_no_stack_exits
    assert_raises(SystemExit) do
      GT::GH.stub(:available?, false) do
        GT::Commands::Sync.new([]).run
      end
    end
  end

  def test_sync_returns_to_original_branch
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("c.txt", message: "on b")

    GT::Git.run("checkout", "branch-a")

    GT::GH.stub(:available?, false) do
      GT::Commands::Sync.new([]).run
    end

    assert_equal "branch-a", GT::Git.current_branch
  end
end
