# frozen_string_literal: true

require_relative "test_helper"

class SyncTest < GTTest
  def test_sync_pulls_main_and_restacks
    create_stack_with_push

    # Simulate a change on remote main: commit, push, then undo locally
    # so origin/main is ahead of local main
    sandbox.run_git("checkout", "main")
    File.write("remote_file.txt", "from remote")
    sandbox.run_git("add", "remote_file.txt")
    sandbox.run_git("commit", "-m", "remote change")
    sandbox.run_git("push", "origin", "main")
    sandbox.run_git("reset", "--hard", "HEAD~1")

    # Go back to branch-a
    sandbox.run_git("checkout", "branch-a")

    run_gt("sync")

    # After sync, should be on the tip
    assert_equal "branch-b", GT::Git.current_branch

    # Main should have the remote change
    sandbox.run_git("checkout", "main")
    assert File.exist?("remote_file.txt")
  end

  def test_sync_with_no_remote_degrades_gracefully
    create_stack_with_push
    sandbox.run_git("checkout", "branch-a")
    sandbox.run_git("remote", "remove", "origin")

    run_gt("sync")

    # Should still restack despite fetch failing
    assert_equal "branch-b", GT::Git.current_branch
  end

  private

  def create_stack_with_push
    File.write("file.txt", "v1")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    sandbox.run_git("checkout", "-b", "branch-a")
    GT::Git.set_parent("branch-a", "main")
    GT::Git.set_fork_point("branch-a", GT::Git.rev_parse("main"))
    File.write("file.txt", "v2")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch a change")
    sandbox.run_git("push", "-u", "origin", "branch-a")

    sandbox.run_git("checkout", "-b", "branch-b")
    GT::Git.set_parent("branch-b", "branch-a")
    GT::Git.set_fork_point("branch-b", GT::Git.rev_parse("branch-a"))
    File.write("file.txt", "v3")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch b change")
    sandbox.run_git("push", "-u", "origin", "branch-b")
  end
end
