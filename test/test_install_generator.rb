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
    assert_file "config/agent_vm_tunnel.json" do |content|
      config = JSON.parse(content)
      assert_equal "firstdraft.io", config["host"]
      assert_equal InstallGeneratorTest.generator_class::FIRSTDRAFT_FINGERPRINT, config["fingerprint"]
      assert_equal "claude", config["provider"]
    end
    assert_file "bin/agent-vm-tunnel", /CONFIG_FILE=/
    assert File.executable?(File.join(destination_root, "bin/agent-vm-tunnel")), "bin/agent-vm-tunnel should be +x"
  end

  def test_custom_host_requires_an_explicit_fingerprint
    run_generator ["--host=preview.example.com"]
    assert_no_file "bin/agent-vm-tunnel"
  end

  def test_accepts_explicit_fingerprint
    fingerprint = "A" * 43 + "="
    run_generator ["--host=preview.example.com", "--fingerprint=#{fingerprint}"]
    assert_file "config/agent_vm_tunnel.json" do |content|
      assert_equal({"host" => "preview.example.com", "fingerprint" => fingerprint, "provider" => "claude"}, JSON.parse(content))
    end
  end

  def test_creates_cloud_vm_setup_script
    run_generator
    assert_file "cloud-vm-setup.sh", /PROVIDER="claude"/
    assert File.executable?(File.join(destination_root, "cloud-vm-setup.sh"))
  end

  def test_setup_script_is_database_agnostic
    run_generator
    assert_file "cloud-vm-setup.sh" do |content|
      # detects the adapter from the lockfile and branches on it
      assert_match(/Gemfile\.lock/, content)
      assert_match(/pg\)/, content)      # PostgreSQL branch
      assert_match(/sqlite\|sqlite3\|""\)/, content)  # SQLite / none = no server
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
      assert_match(/DB_ADAPTER=/, content)
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
      assert_includes commands, "bin/agent-vm-tunnel ensure"
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

  def test_codex_target_generates_maintenance_artifacts_without_claude_hooks
    run_generator ["--provider=codex"]
    assert_file "config/agent_vm_tunnel.json" do |content|
      assert_equal "codex", JSON.parse(content).fetch("provider")
    end
    assert_file "cloud-vm-setup.sh", /PROVIDER="codex"/
    assert_file "bin/agent-vm-tunnel"
    assert_file "AGENTS.md", /Live preview in Codex Cloud/
    assert_no_file ".claude/settings.json"
  end

  def test_both_target_installs_claude_hooks_and_codex_guidance
    run_generator ["--provider=both"]

    assert_file "config/agent_vm_tunnel.json" do |content|
      assert_equal "both", JSON.parse(content).fetch("provider")
    end
    assert_file ".claude/settings.json" do |content|
      json = JSON.parse(content)
      assert runs_preview?(json.dig("hooks", "SessionStart"))
      assert runs_preview?(json.dig("hooks", "UserPromptSubmit"))
    end
    assert_file "AGENTS.md", /Live preview in Codex Cloud/
    assert_file "bin/agent-vm-tunnel", /CLAUDE_PROJECT_DIR/
  end

  def test_codex_guidance_preserves_existing_agents_and_is_idempotent
    File.write(File.join(destination_root, "AGENTS.md"), "# Existing guidance\n\nKeep this.\n")

    run_generator ["--provider=codex"]
    run_generator ["--provider=codex", "--force"]

    assert_file "AGENTS.md" do |content|
      assert_includes content, "# Existing guidance"
      assert_includes content, "Keep this."
      assert_equal 1, content.scan("agent-vm-tunnel:codex:start").length
      assert_equal 1, content.scan("agent-vm-tunnel:codex:end").length
    end
  end

  def test_generated_shell_is_syntactically_valid_and_avoids_global_process_matching
    run_generator ["--provider=generic"]
    %w[bin/agent-vm-tunnel cloud-vm-setup.sh].each do |path|
      absolute = File.join(destination_root, path)
      assert system("bash", "-n", absolute), "#{path} should pass bash -n"
    end
    connector = File.read(File.join(destination_root, "bin/agent-vm-tunnel"))
    refute_includes connector, "bash -c"
    refute_includes connector, "pgrep"
    assert_operator connector.scan("9>&-").length, :>=, 2,
      "owned background processes must close the reconciliation lock descriptor"
  end

  private

  def runs_preview?(groups)
    Array(groups).any? { |g| Array(g["hooks"]).any? { |h| h["command"].to_s.include?("bin/agent-vm-tunnel") } }
  end
end
