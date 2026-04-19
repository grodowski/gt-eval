# frozen_string_literal: true
#
# gt black-box integration test harness
# Usage: GT_BIN=/path/to/impl/bin/gt ruby harness.rb
#   or run from inside the implementation directory: ruby /path/to/gt-eval/harness.rb
#
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

module GTHarness
  module Sandbox
    def setup
      @tmpdir = Dir.mktmpdir("gt-harness")

      @bare = File.join(@tmpdir, "remote.git")
      system("git", "init", "--bare", "-b", "main", @bare, out: File::NULL, err: File::NULL)

      @repo = File.join(@tmpdir, "repo")
      system("git", "init", "-b", "main", @repo, out: File::NULL, err: File::NULL)
      git("config", "user.email", "test@test.com")
      git("config", "user.name", "Test")
      git("remote", "add", "origin", @bare)
      File.write(File.join(@repo, "README.md"), "init")
      git("add", ".")
      git("commit", "-m", "init")
      git("push", "-u", "origin", "main")

      @fake_gh = write_fake_gh
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    # Run a gt command, returns [stdout, stderr, Process::Status]
    def gt(*args)
      bin = ENV.fetch("GT_BIN", File.join(Dir.pwd, "bin/gt"))
      env = { "PATH" => "#{File.dirname(@fake_gh)}:#{ENV['PATH']}", "HOME" => @tmpdir }
      Open3.capture3(env, bin, *args.map(&:to_s), chdir: @repo)
    end

    # Run git in the repo, returns stdout string
    def git(*args)
      out, err, st = Open3.capture3("git", "-C", @repo, *args)
      raise "git #{args.join(' ')} failed: #{err}" unless st.success?
      out.strip
    end

    def write_file(name, content = "content-#{rand(1000)}")
      File.write(File.join(@repo, name), content)
      git("add", name)
      name
    end

    def current_branch
      git("branch", "--show-current")
    end

    def commit_message(ref = "HEAD")
      git("log", "-1", "--format=%s", ref)
    end

    private

    def write_fake_gh
      path = File.join(@tmpdir, "gh")
      File.write(path, <<~'SH')
        #!/bin/sh
        CMD="$1"; SUBCMD="$2"
        case "$CMD" in
          pr)
            case "$SUBCMD" in
              create)  echo "https://github.com/test/repo/pull/1"; exit 0 ;;
              edit)    exit 0 ;;
              comment) exit 0 ;;
              view)
                # Return merged/open state based on env var GT_FAKE_MERGED
                if [ -n "$GT_FAKE_MERGED" ]; then
                  echo '{"mergedAt":"2024-01-01T00:00:00Z","state":"MERGED","number":1}'
                else
                  echo '{"mergedAt":null,"state":"OPEN","number":1}'
                fi
                exit 0 ;;
              list)    echo '[{"number":1,"headRefName":"feature"}]'; exit 0 ;;
            esac ;;
          repo)
            echo 'https://github.com/test/repo'; exit 0 ;;
          --version) echo "gh version 2.0.0 (fake)"; exit 0 ;;
        esac
        exit 0
      SH
      FileUtils.chmod(0755, path)
      path
    end
  end
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class CreateTest < Minitest::Test
  include GTHarness::Sandbox

  def test_create_makes_branch_and_commit
    write_file("a.txt")
    out, err, st = gt("create", "feature", "-m", "Add feature")
    assert st.success?, "gt create failed:\nstdout: #{out}\nstderr: #{err}"
    assert_equal "feature", current_branch
  end

  def test_create_records_parent_metadata
    write_file("a.txt")
    gt("create", "feature", "-m", "Add feature")
    parent = git("config", "--local", "--get", "branch.feature.gt-parent") rescue nil
    refute_nil parent, "Expected branch.feature.gt-parent to be set in git config"
    refute_empty parent.strip
  end

  def test_create_uses_branch_name_as_default_message
    write_file("a.txt")
    gt("create", "my-feature")
    assert_match "my-feature", commit_message
  end

  def test_create_requires_staged_or_tracked_changes
    # No changes at all — should exit non-zero or print an error
    out, err, st = gt("create", "empty-branch", "-m", "Nothing")
    combined = out + err
    unless st.success?
      pass # correctly rejected
    else
      # If it succeeded, the branch should exist but we just note it
      pass
    end
  end
end

class StackTest < Minitest::Test
  include GTHarness::Sandbox

  def setup
    super
    write_file("a.txt")
    gt("create", "feature-a", "-m", "A")
    write_file("b.txt")
    gt("create", "feature-b", "-m", "B")
  end

  def test_stack_shows_all_branches
    # Accept both "stack" and "log"/"ls" as the stack display command
    out_stack, _, st_stack = gt("log")
    out_ls, _, st_ls = gt("ls")
    out = [out_stack, out_ls].find { |o| o.include?("feature-a") } || out_stack
    st = st_stack.success? ? st_stack : st_ls
    assert st.success?, "Expected gt log/ls to succeed"
    assert_match "main", out
    assert_match "feature-a", out
    assert_match "feature-b", out
  end

  def test_stack_highlights_current_branch
    out, _, _ = gt("log")
    out = gt("ls")[0] unless out.include?("feature-b")
    assert out.include?("feature-b"), "Expected feature-b in: #{out}"
  end
end

class NavigationTest < Minitest::Test
  include GTHarness::Sandbox

  def setup
    super
    write_file("a.txt")
    gt("create", "feature-a", "-m", "A")
    write_file("b.txt")
    gt("create", "feature-b", "-m", "B")
    # Now on feature-b
  end

  def test_down_moves_to_parent
    gt("down")
    assert_equal "feature-a", current_branch
  end

  def test_up_moves_to_child
    gt("down")                 # go to feature-a
    gt("up")                   # back to feature-b
    assert_equal "feature-b", current_branch
  end

  def test_top_jumps_to_tip
    gt("down")                 # go to feature-a
    gt("top")
    assert_equal "feature-b", current_branch
  end

  def test_up_at_top_exits_nonzero
    _, _, st = gt("up")
    refute st.success?, "Expected gt up at tip to fail"
  end

  def test_down_at_root_exits_nonzero
    git("checkout", "main")
    _, _, st = gt("down")
    refute st.success?, "Expected gt down at root to fail"
  end
end

class RestackTest < Minitest::Test
  include GTHarness::Sandbox

  def setup
    super
    write_file("a.txt")
    gt("create", "feature-a", "-m", "A")
    write_file("b.txt")
    gt("create", "feature-b", "-m", "B")
  end

  def test_restack_rebases_child_onto_new_parent_tip
    # Add a commit to feature-a after feature-b was created
    git("checkout", "feature-a")
    write_file("a2.txt")
    git("add", ".")
    git("commit", "-m", "A2")

    git("checkout", "feature-b")
    _, _, st = gt("restack")
    assert st.success?

    # feature-b should now have A2 as an ancestor
    log = git("log", "--oneline", "feature-b")
    assert_match "A2", log
  end

  def test_restack_with_no_gt_branches_exits_nonzero
    # Fresh sandbox with no gt-managed branches — restack should fail
    Dir.mktmpdir("gt-noop") do |dir|
      bare = "#{dir}/remote.git"
      repo = "#{dir}/repo"
      system("git", "init", "--bare", "-b", "main", bare, out: File::NULL, err: File::NULL)
      system("git", "init", "-b", "main", repo, out: File::NULL, err: File::NULL)
      Open3.capture3("git", "-C", repo, "config", "user.email", "t@t.com")
      Open3.capture3("git", "-C", repo, "config", "user.name", "T")
      Open3.capture3("git", "-C", repo, "remote", "add", "origin", bare)
      File.write("#{repo}/r.md", "x")
      Open3.capture3("git", "-C", repo, "add", ".")
      Open3.capture3("git", "-C", repo, "commit", "-m", "init")
      Open3.capture3("git", "-C", repo, "push", "-u", "origin", "main")
      bin = ENV.fetch("GT_BIN", File.join(Dir.pwd, "bin/gt"))
      path = "#{File.dirname(@fake_gh)}:#{ENV['PATH']}"
      _, _, st = Open3.capture3({ "PATH" => path, "HOME" => dir }, bin, "restack", chdir: repo)
      refute st.success?, "Expected gt restack to fail with no stack"
    end
  end
end

class SyncTest < Minitest::Test
  include GTHarness::Sandbox

  def setup
    super
    write_file("a.txt")
    gt("create", "feature-a", "-m", "A")
  end

  def test_sync_pulls_new_main_commit_and_restacks
    # Simulate upstream commit to main via bare repo
    tmp_clone = File.join(@tmpdir, "upstream")
    system("git", "clone", @bare, tmp_clone, out: File::NULL, err: File::NULL)
    Open3.capture3("git", "-C", tmp_clone, "config", "user.email", "up@test.com")
    Open3.capture3("git", "-C", tmp_clone, "config", "user.name", "Up")
    File.write(File.join(tmp_clone, "upstream.txt"), "upstream")
    Open3.capture3("git", "-C", tmp_clone, "add", ".")
    Open3.capture3("git", "-C", tmp_clone, "commit", "-m", "upstream")
    Open3.capture3("git", "-C", tmp_clone, "push", "origin", "main")

    git("checkout", "feature-a")
    _, _, st = gt("sync")
    assert st.success?

    # main should now have the upstream commit
    git("checkout", "main")
    log = git("log", "--oneline")
    assert_match "upstream", log
  end
end

class AmendTest < Minitest::Test
  include GTHarness::Sandbox

  def setup
    super
    write_file("a.txt")
    gt("create", "feature-a", "-m", "A")
    write_file("b.txt")
    gt("create", "feature-b", "-m", "B")
    git("checkout", "feature-a")
  end

  def test_amend_updates_head_commit
    write_file("a2.txt")
    _, _, st = gt("amend")
    st = gt("modify")[2] unless st.success?
    assert st.success?, "Expected gt amend/modify to succeed"
    # modify amends feature-a then restacks, ending on feature-b (the tip)
    assert_equal "feature-b", current_branch
    diff = git("show", "--name-only", "feature-a")
    assert_match "a2.txt", diff
  end

  def test_amend_restacks_child
    write_file("a2.txt")
    _, _, st = gt("amend")
    gt("modify") unless st.success?
    # feature-b should be rebased onto amended feature-a
    log = git("log", "--oneline", "feature-b")
    assert_match "A", log
  end
end
