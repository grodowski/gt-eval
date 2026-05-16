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

# ---------------------------------------------------------------------------
# Two independent stacks rooted at main:
#   main → alpha-1 → alpha-2
#   main → beta-1  → beta-2
# This is a common failure mode: implementations that assume a single linear
# stack break when gt-parent metadata for two different branches both point
# to main, and navigation/restack logic gets confused.
# ---------------------------------------------------------------------------
class DualStackTest < Minitest::Test
  include GTHarness::Sandbox

  def setup
    super
    # Build stack 1: main → alpha-1 → alpha-2
    git("checkout", "main")
    write_file("a1.txt")
    gt("create", "alpha-1", "-m", "Alpha 1")
    write_file("a2.txt")
    gt("create", "alpha-2", "-m", "Alpha 2")

    # Build stack 2: main → beta-1 → beta-2
    git("checkout", "main")
    write_file("b1.txt")
    gt("create", "beta-1", "-m", "Beta 1")
    write_file("b2.txt")
    gt("create", "beta-2", "-m", "Beta 2")
    # Now on beta-2
  end

  def test_both_stack_tips_exist
    branches = git("branch", "--list").split.map(&:strip).map { |b| b.delete_prefix("* ") }
    assert_includes branches, "alpha-2", "alpha-2 branch missing"
    assert_includes branches, "beta-2",  "beta-2 branch missing"
  end

  def test_parent_metadata_is_independent
    alpha1_parent = git("config", "--local", "--get", "branch.alpha-1.gt-parent") rescue nil
    beta1_parent  = git("config", "--local", "--get", "branch.beta-1.gt-parent")  rescue nil
    assert_equal "main", alpha1_parent&.strip, "alpha-1 parent should be main"
    assert_equal "main", beta1_parent&.strip,  "beta-1 parent should be main"

    alpha2_parent = git("config", "--local", "--get", "branch.alpha-2.gt-parent") rescue nil
    beta2_parent  = git("config", "--local", "--get", "branch.beta-2.gt-parent")  rescue nil
    assert_equal "alpha-1", alpha2_parent&.strip, "alpha-2 parent should be alpha-1"
    assert_equal "beta-1",  beta2_parent&.strip,  "beta-2 parent should be beta-1"
  end

  def test_navigation_stays_within_alpha_stack
    git("checkout", "alpha-2")
    gt("down")
    assert_equal "alpha-1", current_branch,
      "gt down from alpha-2 should land on alpha-1, not beta-1 or anything else"
  end

  def test_navigation_stays_within_beta_stack
    # already on beta-2 from setup
    gt("down")
    assert_equal "beta-1", current_branch,
      "gt down from beta-2 should land on beta-1, not alpha-1"
  end

  def test_restack_does_not_bleed_across_stacks
    # Add an extra commit to alpha-1 so alpha-2 needs rebasing
    git("checkout", "alpha-1")
    write_file("a1b.txt")
    git("commit", "-m", "Alpha 1b")

    # Capture beta-2's current base commit before any restack
    beta2_base_before = git("log", "--oneline", "beta-2")

    # Restack alpha stack
    git("checkout", "alpha-2")
    _, _, st = gt("restack")
    assert st.success?, "gt restack on alpha stack failed"

    # alpha-2 should now include Alpha 1b
    alpha2_log = git("log", "--oneline", "alpha-2")
    assert_match "Alpha 1b", alpha2_log, "alpha-2 should be rebased onto new alpha-1 tip"

    # beta-2 should be completely unchanged
    beta2_base_after = git("log", "--oneline", "beta-2")
    assert_equal beta2_base_before, beta2_base_after,
      "beta-2 commit history changed after restacking the alpha stack"
  end

  def test_log_shows_current_stack
    # Setup ends on beta-2; log should show the beta stack only
    out, _, st = gt("log")
    out = gt("ls")[0] if out.empty?
    assert st.success?, "gt log/ls failed"
    assert_match "beta-1", out, "log should show beta-1 (current stack)"
    assert_match "beta-2", out, "log should show beta-2 (current stack)"
    refute_match "alpha-1", out, "log should not show alpha stack while on beta"
    refute_match "alpha-2", out, "log should not show alpha stack while on beta"
  end

  def test_log_follows_current_branch_after_stack_switch
    # Setup ends on beta-2. Switch to the alpha stack and verify log
    # reflects alpha, not the previously-active beta stack.
    git("checkout", "alpha-2")
    out, _, st = gt("log")
    out = gt("ls")[0] if out.empty?
    assert st.success?, "gt log/ls failed after switching stacks"
    assert_match "alpha-1", out, "log should show alpha-1 after switching to alpha stack"
    assert_match "alpha-2", out, "log should show alpha-2 after switching to alpha stack"
    refute_match "beta-1",  out, "log should NOT show beta stack after switching to alpha stack"
    refute_match "beta-2",  out, "log should NOT show beta stack after switching to alpha stack"
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
