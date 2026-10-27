#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"

class HandbookWorkflowTest < Minitest::Test
  def setup
    path = File.expand_path("../.github/workflows/handbook.yml", __dir__)
    @workflow = YAML.safe_load(File.read(path))
  end

  def test_pull_requests_build_and_check_without_publication_credentials
    assert @workflow.fetch("on").key?("pull_request")
    assert_equal ["paths"], @workflow.fetch("on").fetch("pull_request").keys,
      "Check relevant PRs regardless of their target branch"
    assert_equal({}, @workflow.fetch("permissions"))
    build = @workflow.fetch("jobs").fetch("build")
    refute build.key?("if"), "The build must not be skipped for PRs"
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

  def test_automatic_runs_cover_handbook_inputs_and_checks
    paths = %w[docs/** CHANGELOG.md .github/workflows/handbook.yml tests/handbook*]
    %w[pull_request push].each do |event|
      assert_equal paths, @workflow.fetch("on").fetch(event).fetch("paths"),
        "Include documentation, canonical changelog, workflow, and handbook checks"
    end
  end

  def test_only_checked_main_pushes_and_manual_runs_can_publish
    assert_equal ["main"], @workflow.fetch("on").fetch("push").fetch("branches")
    assert_equal %w[branches paths], @workflow.fetch("on").fetch("push").keys.sort
    assert_equal %w[pull_request push workflow_dispatch], @workflow.fetch("on").keys.sort
    assert_nil @workflow.fetch("on").fetch("workflow_dispatch")
    assert_equal %w[build deploy], @workflow.fetch("jobs").keys.sort
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
end
