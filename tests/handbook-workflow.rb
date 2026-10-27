#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"
require "tmpdir"
require "fileutils"
require "open3"

class HandbookWorkflowTest < Minitest::Test
  def setup
    path = File.expand_path("../.github/workflows/handbook.yml", __dir__)
    @workflow = YAML.safe_load(File.read(path))
  end

  def test_pull_requests_build_and_check_without_publication_credentials
    assert @workflow.fetch("on").key?("pull_request")
    assert_nil @workflow.fetch("on").fetch("pull_request"),
      "Check every PR so the check can be required; no path or branch filters"
    assert_equal({}, @workflow.fetch("permissions"))
    build = @workflow.fetch("jobs").fetch("build")
    assert_equal "changes", build.fetch("needs")
    assert_equal "needs.changes.outputs.handbook == 'true'", build.fetch("if")
    assert_equal({"contents" => "read"}, build.fetch("permissions"))
    commands = build.fetch("steps").map { |step| step["run"] }.compact
    assert_includes commands, "bundle exec jekyll build"
    assert_equal "production", build.fetch("env").fetch("JEKYLL_ENV")
    assert_includes commands, "bash tests/handbook.sh"
    build_step = build.fetch("steps").find { |step| step["run"] == "bundle exec jekyll build" }
    assert_equal "docs/handbook", build_step.fetch("working-directory")
    refute_match(/secrets\.|CLOUDFLARE|deploy-pages|configure-pages/, build.to_yaml)
    checkout = build.fetch("steps").find { |step| step.fetch("uses", "").start_with?("actions/checkout@") }
    assert_equal false, checkout.fetch("with").fetch("persist-credentials")
  end

  def test_main_pushes_publish_only_for_handbook_inputs_and_checks
    paths = %w[docs/** CHANGELOG.md .github/workflows/handbook.yml tests/handbook*]
    assert_equal paths, @workflow.fetch("on").fetch("push").fetch("paths"),
      "Include documentation, canonical changelog, workflow, and handbook checks"
  end

  def test_only_checked_main_pushes_and_manual_runs_can_publish
    assert_equal ["main"], @workflow.fetch("on").fetch("push").fetch("branches")
    assert_equal %w[branches paths], @workflow.fetch("on").fetch("push").keys.sort
    assert_equal %w[pull_request push workflow_dispatch], @workflow.fetch("on").keys.sort
    assert_nil @workflow.fetch("on").fetch("workflow_dispatch")
    assert_equal %w[build changes deploy handbook], @workflow.fetch("jobs").keys.sort
    main_publication = "(github.event_name == 'push' || github.event_name == 'workflow_dispatch') && github.ref == 'refs/heads/main'"
    build = @workflow.fetch("jobs").fetch("build")
    upload = build.fetch("steps").find do |step|
      step.fetch("uses", "").start_with?("actions/upload-pages-artifact@")
    end
    refute_nil upload, "Checked output must be passed through a Pages artifact"
    assert_equal main_publication, upload.fetch("if")
    assert_equal "docs/handbook/_site", upload.fetch("with").fetch("path")
    assert_equal upload, build.fetch("steps").last, "Never upload before output checks pass"
    deploy = @workflow.fetch("jobs").fetch("deploy")
    assert_equal main_publication, deploy.fetch("if")
    assert_equal "build", deploy.fetch("needs")
    assert_equal({"pages" => "write", "id-token" => "write"}, deploy.fetch("permissions"))
    assert_equal "github-pages", deploy.fetch("environment").fetch("name")
    steps = deploy.fetch("steps")
    assert_equal 1, steps.length, "Privileged deployment must not check out or run source"
    assert_match(/\Aactions\/deploy-pages@[0-9a-f]{40}\z/, steps.first.fetch("uses"))
    refute_match(/secrets\.|CLOUDFLARE|configure-pages/, @workflow.to_yaml)
  end

  def test_gate_requires_successful_detection_and_expected_build_result
    gate = @workflow.fetch("jobs").fetch("handbook")
    assert_equal "Handbook", gate.fetch("name")
    assert_equal "always()", gate.fetch("if")
    assert_equal %w[changes build], gate.fetch("needs")
    %w[success failure cancelled skipped].repeated_permutation(2) do |changes, build|
      %w[true false missing].each do |changed|
        _, status = Open3.capture2e(
          {"CHANGES_RESULT" => changes, "HANDBOOK_CHANGED" => changed, "BUILD_RESULT" => build},
          "bash", "-e", "-c", gate.fetch("steps").first.fetch("run")
        )
        expected = changes == "success" &&
          ((changed == "true" && build == "success") || (changed == "false" && build == "skipped"))
        assert_equal expected, status.success?, "#{changes}/#{changed}/#{build}"
      end
    end
  end

  def git(directory, *args)
    output, status = Open3.capture2e("git", *args, chdir: directory)
    assert status.success?, output
    output.strip
  end

  def test_real_git_diffs_select_handbook_paths_and_preserve_manual_runs
    changes = @workflow.fetch("jobs").fetch("changes")
    assert_equal({"contents" => "read"}, changes.fetch("permissions"))
    checkout = changes.fetch("steps").first
    assert_equal false, checkout.fetch("with").fetch("persist-credentials")
    assert_equal 0, checkout.fetch("with").fetch("fetch-depth")
    script = changes.fetch("steps").find { |step| step["id"] == "paths" }.fetch("run")
    Dir.mktmpdir("handbook-paths") do |directory|
      git(directory, "init", "-q")
      git(directory, "config", "user.name", "Workflow test")
      git(directory, "config", "user.email", "workflow@example.invalid")
      git(directory, "commit", "--allow-empty", "-qm", "Initial")
      output_path = File.join(directory, "output")
      detect = lambda do |base, head, event = "pull_request"|
        File.write(output_path, "")
        output, status = Open3.capture2e(
          {"EVENT_NAME" => event, "BASE_SHA" => base, "HEAD_SHA" => head, "GITHUB_OUTPUT" => output_path},
          "bash", "-e", "-c", script, chdir: directory
        )
        [File.read(output_path).strip, status.success?, output]
      end
      paths = %w[Sources/macnotif/main.swift README.md CONTRIBUTING.md
        .github/workflows/validate.yml tests/validate-workflow.rb docs/handbook/site/index.md
        docs/handbook/Gemfile.lock CHANGELOG.md .github/workflows/handbook.yml
        tests/handbook.sh tests/handbook-workflow.rb]
      paths.each_with_index do |path, index|
        base = git(directory, "rev-parse", "HEAD")
        FileUtils.mkdir_p(File.dirname(File.join(directory, path)))
        File.write(File.join(directory, path), "test\n")
        git(directory, "add", path)
        git(directory, "commit", "-qm", "Add fixture")
        result, success, output = detect.call(base, "HEAD")
        assert success, output
        assert_equal "handbook=#{index >= 5}", result, path
      end
      base = git(directory, "rev-parse", "HEAD")
      git(directory, "rm", "docs/handbook/site/index.md")
      git(directory, "commit", "-qm", "Delete page")
      assert_equal ["handbook=true", true], detect.call(base, "HEAD").first(2)
      assert_equal ["handbook=false", true], detect.call("HEAD", "HEAD").first(2)
      %w[push workflow_dispatch].each do |event|
        assert_equal ["handbook=true", true], detect.call("", "", event).first(2)
      end
      result, success, = detect.call("invalid-base", "HEAD")
      refute success, "Invalid comparisons must not silently skip handbook checks"
      assert_empty result
    end
  end
end
