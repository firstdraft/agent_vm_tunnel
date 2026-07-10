# frozen_string_literal: true

require_relative "agent_vm_tunnel/version"
require_relative "agent_vm_tunnel/configuration"

# Public live-preview URLs for Rails apps built inside Codex, Claude, and other
# outbound-only cloud environments, served through a chisel reverse tunnel.
#
# The library half is tiny: a Railtie that teaches Rails host authorization and
# Action Cable about the tunnel's public hosts so tunneled page loads and
# WebSockets aren't rejected. The moving parts that actually hold the tunnel
# open are shell, not Ruby — they have to repair the environment's Ruby before
# Bundler can load — so the install generator drops provider-aware setup and
# lifecycle files into the host app rather than the gem running them.
module AgentVmTunnel
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the tunnel, typically in a Rails initializer:
    #
    #   AgentVmTunnel.configure do |config|
    #     config.host = "preview.example.com"   # your own agent-vm-tunnel box
    #   end
    #
    # With no configuration it targets the default firstdraft.io tunnel.
    def configure
      yield configuration if block_given?
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

require_relative "agent_vm_tunnel/railtie"
