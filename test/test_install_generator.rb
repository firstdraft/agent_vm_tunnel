# frozen_string_literal: true

require "test_helper"
require "json"
require "rails/generators"
require "rails/generators/test_case"
require "generators/agent_vm_tunnel/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests AgentVmTunnel::Generators::InstallGenerator
  destination File.expand_path("../tmp/generator", __dir__)
  setup :prepare_destination

  def test_creates_executable_preview_with_default_host
    run_generator
    assert_file "bin/agent-vm-tunnel" do |content|
      assert_match "https://tunnel.firstdraft.io", content
      assert_match "https://firstdraft.io/tunnel", content
      assert_match InstallGeneratorTest.generator_class::FIRSTDRAFT_FINGERPRINT, content
    end
    assert File.executable?(File.join(destination_root, "bin/agent-vm-tunnel")), "bin/agent-vm-tunnel should be +x"
  end

  def test_honors_custom_host_and_blanks_unknown_fingerprint
    run_generator ["--host=preview.example.com"]
    assert_file "bin/agent-vm-tunnel" do |content|
      assert_match "https://tunnel.preview.example.com", content
      assert_match "https://preview.example.com/tunnel", content
      assert_match(/FINGERPRINT=""/, content)
    end
  end

  def test_accepts_explicit_fingerprint
    run_generator ["--host=preview.example.com", "--fingerprint=ABC123="]
    assert_file "bin/agent-vm-tunnel", /FINGERPRINT="ABC123="/
  end

  def test_creates_cloud_vm_setup_script
    run_generator
    assert_file "cloud-vm-setup.sh", /tunnel\.firstdraft\.io/
    assert File.executable?(File.join(destination_root, "cloud-vm-setup.sh"))
  end

  def test_setup_script_is_database_agnostic
    run_generator
    assert_file "cloud-vm-setup.sh" do |content|
      # detects the adapter from the lockfile and branches on it
      assert_match(/Gemfile\.lock/, content)
      assert_match(/pg\)/, content)      # PostgreSQL branch
      assert_match(/sqlite3 \| ""\)/, content)  # SQLite / none = no server
      # no unconditional Postgres install
      refute_match(/^apt-get install -y -qq postgresql$/, content)
    end
  end

  def test_setup_script_reads_ruby_version_without_hardcoded_fallback
    run_generator
    assert_file "cloud-vm-setup.sh" do |content|
      assert_match(/\.ruby-version/, content)
      refute_match(/RUBY_VERSION:-4\.0\.3/, content)  # no firstdraft-specific default
    end
  end

  def test_preview_only_starts_a_daemon_for_server_databases
    run_generator
    assert_file "bin/agent-vm-tunnel" do |content|
      assert_match(/db_gem=/, content)
      assert_match(/pg\)/, content)
    end
  end

  def test_creates_claude_hooks_when_absent
    run_generator
    assert_file ".claude/settings.json" do |content|
      json = JSON.parse(content)
      %w[SessionStart UserPromptSubmit].each do |event|
        assert runs_preview?(json.dig("hooks", event)), "#{event} should run bin/agent-vm-tunnel"
      end
    end
  end

  def test_merges_into_existing_settings_without_clobbering
    FileUtils.mkdir_p(File.join(destination_root, ".claude"))
    existing = {
      "hooks" => {
        "SessionStart" => [{"hooks" => [{"type" => "command", "command" => "echo hi"}]}]
      },
      "permissions" => {"allow" => ["Bash(ls:*)"]}
    }
    File.write(File.join(destination_root, ".claude/settings.json"), JSON.pretty_generate(existing))

    run_generator

    assert_file ".claude/settings.json" do |content|
      json = JSON.parse(content)
      # untouched keys survive
      assert_equal ["Bash(ls:*)"], json.dig("permissions", "allow")
      # the pre-existing SessionStart hook is preserved AND ours is added
      commands = json.dig("hooks", "SessionStart").flat_map { |g| g["hooks"].map { |h| h["command"] } }
      assert_includes commands, "echo hi"
      assert_includes commands, "bin/agent-vm-tunnel"
      # UserPromptSubmit gets added fresh
      assert runs_preview?(json.dig("hooks", "UserPromptSubmit"))
    end
  end

  def test_is_idempotent_on_hooks
    run_generator
    first = File.read(File.join(destination_root, ".claude/settings.json"))
    run_generator ["--force"]
    second = File.read(File.join(destination_root, ".claude/settings.json"))
    assert_equal JSON.parse(first), JSON.parse(second), "re-running should not duplicate hooks"
  end

  private

  def runs_preview?(groups)
    Array(groups).any? { |g| Array(g["hooks"]).any? { |h| h["command"].to_s.include?("bin/agent-vm-tunnel") } }
  end
end
