# frozen_string_literal: true

require "json"

module AgentVmTunnel
  # Everything the Railtie needs to know to let tunnel traffic past Rails' host
  # authorization and Action Cable origin checks. Sensible defaults target the
  # public firstdraft.io tunnel; point `host` at your own agent-vm-tunnel box to
  # self-host.
  class Configuration
    # The tunnel's base domain. Previews live at <name>.<host>. Overridable
    # without code via the AGENT_VM_TUNNEL_HOST env var.
    attr_writer :host

    # Rails environments the Railtie configures. The tunnel is a development
    # preview aid, so only :development by default.
    attr_accessor :environments

    # Escape hatches for extra allowed hosts / Action Cable origins. Rails and
    # Caddy preserve the public Host and scheme, so Action Cable's built-in
    # exact same-origin check is sufficient for normal tunneled requests. We do
    # not add a wildcard origin: sibling previews are separate trust domains.
    attr_accessor :extra_allowed_hosts, :extra_allowed_origins

    DEFAULT_HOST = "firstdraft.io"

    def initialize
      @host = ENV["AGENT_VM_TUNNEL_HOST"]
      @environments = [:development]
      @extra_allowed_hosts = []
      @extra_allowed_origins = []
    end

    def host
      @host || project_settings.fetch("host", DEFAULT_HOST)
    end

    # Values for `config.hosts` — a leading dot allows every opaque preview
    # subdomain plus the apex.
    def allowed_hosts
      [".#{host}", *extra_allowed_hosts]
    end

    # Explicit cross-origin exceptions only. Same-origin requests are accepted
    # by Action Cable itself; broad sibling-domain exceptions would let one
    # preview initiate authenticated WebSockets to another preview.
    def allowed_origins
      extra_allowed_origins
    end

    def applies_to?(env)
      environments.map(&:to_sym).include?(env.to_sym)
    end

    private

    def project_settings
      return @project_settings if defined?(@project_settings)

      @project_settings = begin
        path = if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          Rails.root.join("config/agent_vm_tunnel.json")
        end
        path&.file? ? JSON.parse(path.read) : {}
      rescue JSON::ParserError
        raise AgentVmTunnel::Error, "config/agent_vm_tunnel.json is not valid JSON"
      end
    end
  end
end
