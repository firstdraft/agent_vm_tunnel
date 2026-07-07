# frozen_string_literal: true

module AgentVmTunnel
  # Everything the Railtie needs to know to let tunnel traffic past Rails' host
  # authorization and Action Cable origin checks. Sensible defaults target the
  # public firstdraft.io tunnel; point `host` at your own agent-vm-tunnel box to
  # self-host.
  class Configuration
    # The tunnel's base domain. Previews live at <name>.<host>. Overridable
    # without code via the AGENT_VM_TUNNEL_HOST env var.
    attr_accessor :host

    # Rails environments the Railtie configures. The tunnel is a development
    # preview aid, so only :development by default.
    attr_accessor :environments

    # Also accept plain localhost WebSocket origins (handy when the same app is
    # opened directly, e.g. a local run or an SSH port-forward).
    attr_accessor :allow_localhost

    # Escape hatches for extra allowed hosts / Action Cable origins, merged in
    # alongside the computed tunnel entries.
    attr_accessor :extra_allowed_hosts, :extra_allowed_origins

    DEFAULT_HOST = "firstdraft.io"

    def initialize
      @host = ENV.fetch("AGENT_VM_TUNNEL_HOST", DEFAULT_HOST)
      @environments = [:development]
      @allow_localhost = true
      @extra_allowed_hosts = []
      @extra_allowed_origins = []
    end

    # Values for `config.hosts` — a leading dot allows every subdomain (the
    # <github-login>.<host> previews) plus the apex.
    def allowed_hosts
      [".#{host}", *extra_allowed_hosts]
    end

    # Values for `config.action_cable.allowed_request_origins`. Regexps, because
    # each attendee gets a different subdomain.
    def allowed_origins
      origins = [%r{\Ahttps://[a-z0-9-]+\.#{Regexp.escape(host)}\z}]
      origins << %r{\Ahttp://localhost:\d+\z} if allow_localhost
      origins + extra_allowed_origins
    end

    def applies_to?(env)
      environments.map(&:to_sym).include?(env.to_sym)
    end
  end
end
