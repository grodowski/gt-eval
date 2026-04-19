# frozen_string_literal: true

require_relative "test_helper"

class SyncTest < Minitest::Test
  include GitSandbox

  def test_sync_pulls_main_and_restacks
    with_sandbox do |local_dir, remote_dir|
      # Create a stack on top of main
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      # Simulate main advancing (someone else pushed to main)
      Dir.mktmpdir("gt-test-other") do |other_dir|
        git!(other_dir, "git", "clone", remote_dir, ".")
        git!(other_dir, "git", "config", "user.email", "other@test.com")
        git!(other_dir, "git", "config", "user.name", "Other")
        File.write(File.join(other_dir, "main_extra.txt"), "main extra\n")
        git!(other_dir, "git", "add", "main_extra.txt")
        git!(other_dir, "git", "commit", "-m", "Main advance")
        git!(other_dir, "git", "push", "origin", "main")
      end

      # Run gt sync from feature-a
      git!(local_dir, "git", "checkout", "feature-a")
      gt(local_dir, "sync")

      # feature-a should be rebased onto the updated main
      local_main_tip = git!(local_dir, "git", "rev-parse", "main")
      feature_a_parent = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feature-a")
      assert_equal local_main_tip, feature_a_parent
    end
  end

  def test_sync_on_unmanaged_branch_still_pulls_main
    with_sandbox do |local_dir, remote_dir|
      # Simulate main advancing
      Dir.mktmpdir("gt-test-other") do |other_dir|
        git!(other_dir, "git", "clone", remote_dir, ".")
        git!(other_dir, "git", "config", "user.email", "other@test.com")
        git!(other_dir, "git", "config", "user.name", "Other")
        File.write(File.join(other_dir, "main_extra.txt"), "extra\n")
        git!(other_dir, "git", "add", "main_extra.txt")
        git!(other_dir, "git", "commit", "-m", "Main advance")
        git!(other_dir, "git", "push", "origin", "main")
      end

      # sync from main
      gt(local_dir, "sync")

      # local main should be updated
      assert File.exist?(File.join(local_dir, "main_extra.txt"))
    end
  end

  def test_sync_restacks_whole_stack
    with_sandbox do |local_dir, remote_dir|
      File.write(File.join(local_dir, "a.txt"), "a\n")
      git!(local_dir, "git", "add", "a.txt")
      gt(local_dir, "create", "feature-a", "-m", "A")

      File.write(File.join(local_dir, "b.txt"), "b\n")
      git!(local_dir, "git", "add", "b.txt")
      gt(local_dir, "create", "feature-b", "-m", "B")

      # Advance main
      Dir.mktmpdir("gt-test-other") do |other_dir|
        git!(other_dir, "git", "clone", remote_dir, ".")
        git!(other_dir, "git", "config", "user.email", "other@test.com")
        git!(other_dir, "git", "config", "user.name", "Other")
        File.write(File.join(other_dir, "main2.txt"), "m2\n")
        git!(other_dir, "git", "add", "main2.txt")
        git!(other_dir, "git", "commit", "-m", "Main advance")
        git!(other_dir, "git", "push", "origin", "main")
      end

      git!(local_dir, "git", "checkout", "feature-b")
      gt(local_dir, "sync")

      # feature-a should be rebased onto updated main
      local_main_tip    = git!(local_dir, "git", "rev-parse", "main")
      feature_a_parent  = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feature-a")
      assert_equal local_main_tip, feature_a_parent

      # feature-b should be rebased onto updated feature-a
      feature_a_tip    = git!(local_dir, "git", "rev-parse", "feature-a")
      feature_b_parent = git!(local_dir, "git", "log", "--pretty=%P", "-1", "feature-b")
      assert_equal feature_a_tip, feature_b_parent
    end
  end
end
