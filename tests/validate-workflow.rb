#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"
require "tmpdir"
require "fileutils"
require "open3"

class ValidateWorkflowTest < Minitest::Test
  def setup
    @workflow = YAML.safe_load(File.read(File.expand_path("../.github/workflows/validate.yml", __dir__)))
    @jobs = @workflow.fetch("jobs")
    @detect = @jobs.fetch("changes").fetch("steps").find { |step| step["id"] == "paths" }.fetch("run")
    @gate = @jobs.fetch("validate").fetch("steps").first.fetch("run")
  end

  def test_every_pr_reports_a_gate_and_builds_remain_conditional
    assert @workflow.fetch("on").key?("pull_request")
    assert_nil @workflow.fetch("on").fetch("pull_request")
    assert_equal({"contents" => "read"}, @workflow.fetch("permissions"))
    assert_equal "always()", @jobs.fetch("validate").fetch("if")
    assert_equal "Validate", @jobs.fetch("validate").fetch("name")
    assert_equal %w[changes build-and-test], @jobs.fetch("validate").fetch("needs")
    assert_equal "changes", @jobs.fetch("build-and-test").fetch("needs")
    assert_equal "needs.changes.outputs.app == 'true'", @jobs.fetch("build-and-test").fetch("if")
    assert_equal false, @jobs.fetch("build-and-test").fetch("strategy").fetch("fail-fast")
    assert_equal %w[arm64 x86_64], @jobs.fetch("build-and-test").fetch("strategy")
      .fetch("matrix").fetch("include").map { |item| item.fetch("architecture") }
    assert_includes @workflow.fetch("on").fetch("push").fetch("paths"), "tests/validate-workflow.rb"
  end

  def test_gate_rejects_failures_cancellations_and_unexpected_skips
    %w[success failure cancelled skipped].repeated_permutation(2) do |changes, build|
      %w[true false missing].each do |app|
        _, status = Open3.capture2e(
          {"CHANGES_RESULT" => changes, "APP_CHANGED" => app, "BUILD_RESULT" => build},
          "bash", "-e", "-c", @gate
        )
        expected = changes == "success" &&
          ((app == "true" && build == "success") || (app == "false" && build == "skipped"))
        assert_equal expected, status.success?, "#{changes}/#{app}/#{build}"
      end
    end
  end

  def git(directory, *args)
    output, status = Open3.capture2e("git", *args, chdir: directory)
    assert status.success?, output
    output.strip
  end

  def detect(directory, base, head, event = "pull_request")
    output_path = File.join(directory, "output")
    File.write(output_path, "")
    output, status = Open3.capture2e(
      {"EVENT_NAME" => event, "BASE_SHA" => base, "HEAD_SHA" => head, "GITHUB_OUTPUT" => output_path},
      "bash", "-e", "-c", @detect, chdir: directory
    )
    [File.read(output_path).strip, status.success?, output]
  end

  def test_real_git_diffs_select_app_paths_and_surface_errors
    Dir.mktmpdir("validate-paths") do |directory|
      git(directory, "init", "-q")
      git(directory, "config", "user.name", "Workflow test")
      git(directory, "config", "user.email", "workflow@example.invalid")
      git(directory, "commit", "--allow-empty", "-qm", "Initial")
      paths = %w[README.md CHANGELOG.md CONTRIBUTING.md docs/handbook/site/index.md
        tests/handbook-workflow.rb Sources/macnotif/main.swift Resources/Info.plist
        Package.swift Package.resolved scripts/build.sh templates/macnotif.rb.in
        tests/release-smoke.sh tests/formula-template.sh .github/workflows/validate.yml
        tests/validate-workflow.rb]
      paths.each_with_index do |path, index|
        base = git(directory, "rev-parse", "HEAD")
        FileUtils.mkdir_p(File.dirname(File.join(directory, path)))
        File.write(File.join(directory, path), "test\n")
        git(directory, "add", path)
        git(directory, "commit", "-qm", "Add fixture")
        result, success, output = detect(directory, base, "HEAD")
        assert success, output
        assert_equal "app=#{index >= 5}", result, path
      end
      base = git(directory, "rev-parse", "HEAD")
      git(directory, "rm", "Sources/macnotif/main.swift")
      git(directory, "commit", "-qm", "Delete source")
      assert_equal ["app=true", true], detect(directory, base, "HEAD").first(2)
      assert_equal ["app=false", true], detect(directory, "HEAD", "HEAD").first(2)
      assert_equal ["app=true", true], detect(directory, "", "", "push").first(2)
      result, success, = detect(directory, "invalid-base", "HEAD")
      refute success, "Invalid comparisons must not silently skip builds"
      assert_empty result
    end
  end
end
