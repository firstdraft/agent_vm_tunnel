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

  def test_does_not_allow_cross_tenant_action_cable_origins
    assert_empty AgentVmTunnel.configuration.allowed_origins
  end

  def test_explicit_extra_origins_are_preserved
    origin = "https://trusted.example.test"
    AgentVmTunnel.configure { |c| c.extra_allowed_origins = [origin] }
    assert_equal [origin], AgentVmTunnel.configuration.allowed_origins
  end

  def test_applies_only_to_configured_environments
    config = AgentVmTunnel.configuration
    assert config.applies_to?(:development)
    assert config.applies_to?("development")
    refute config.applies_to?(:production)
  end
end
