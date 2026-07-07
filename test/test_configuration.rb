# frozen_string_literal: true

require "test_helper"

class TestConfiguration < Minitest::Test
  def setup
    AgentVmTunnel.reset_configuration!
  end

  def teardown
    ENV.delete("AGENT_VM_TUNNEL_HOST")
    AgentVmTunnel.reset_configuration!
  end

  def test_it_has_a_version_number
    refute_nil AgentVmTunnel::VERSION
  end

  def test_defaults_to_the_firstdraft_tunnel
    assert_equal "firstdraft.io", AgentVmTunnel.configuration.host
  end

  def test_host_is_overridable_via_env
    ENV["AGENT_VM_TUNNEL_HOST"] = "preview.example.com"
    AgentVmTunnel.reset_configuration!
    assert_equal "preview.example.com", AgentVmTunnel.configuration.host
  end

  def test_configure_block_sets_host
    AgentVmTunnel.configure { |c| c.host = "tun.example.org" }
    assert_equal "tun.example.org", AgentVmTunnel.configuration.host
  end

  def test_allowed_hosts_covers_all_subdomains
    assert_equal [".firstdraft.io"], AgentVmTunnel.configuration.allowed_hosts
  end

  def test_allowed_hosts_includes_extras
    AgentVmTunnel.configure { |c| c.extra_allowed_hosts = [".example.dev"] }
    assert_equal [".firstdraft.io", ".example.dev"], AgentVmTunnel.configuration.allowed_hosts
  end

  def test_allowed_origins_match_preview_subdomains
    origin = AgentVmTunnel.configuration.allowed_origins.first
    assert_match origin, "https://ada.firstdraft.io"
    assert_match origin, "https://some-user-99.firstdraft.io"
    refute_match origin, "https://firstdraft.io.evil.com"
    refute_match origin, "http://ada.firstdraft.io"
  end

  def test_allowed_origins_include_localhost_by_default
    assert AgentVmTunnel.configuration.allowed_origins.any? { |o| o.match?("http://localhost:3000") }
  end

  def test_localhost_can_be_disabled
    AgentVmTunnel.configure { |c| c.allow_localhost = false }
    refute AgentVmTunnel.configuration.allowed_origins.any? { |o| o.match?("http://localhost:3000") }
  end

  def test_custom_host_is_regexp_escaped
    AgentVmTunnel.configure { |c| c.host = "preview.example.com" }
    origin = AgentVmTunnel.configuration.allowed_origins.first
    assert_match origin, "https://ada.preview.example.com"
    # the dots are literal, not any-char wildcards
    refute_match origin, "https://ada.previewXexampleYcom"
  end

  def test_applies_only_to_configured_environments
    config = AgentVmTunnel.configuration
    assert config.applies_to?(:development)
    assert config.applies_to?("development")
    refute config.applies_to?(:production)
  end
end
