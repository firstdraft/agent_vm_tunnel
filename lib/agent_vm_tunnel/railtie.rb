# frozen_string_literal: true

require "rails"

module AgentVmTunnel
  # Teaches a host Rails app to accept tunnel traffic without any hand-editing of
  # config/environments: it allows the tunnel's wildcard host (so host
  # authorization doesn't return "Blocked hosts"). Action Cable already allows
  # exact same-origin connections; only explicit application-provided origin
  # exceptions are merged. Only configured environments are touched.
  class Railtie < ::Rails::Railtie
    # `config.hosts` is consumed when the middleware stack is assembled, so the
    # allowed host has to be in place before that — hence `before:
    # :build_middleware_stack`.
    initializer "agent_vm_tunnel.allow_hosts", before: :build_middleware_stack do |app|
      config = AgentVmTunnel.configuration
      next unless config.applies_to?(Rails.env)

      new_hosts = config.allowed_hosts - app.config.hosts
      app.config.hosts.concat(new_hosts)
    end

    # Action Cable populates its server config (including a development localhost
    # default) during boot, so we append our origins in after_initialize — after
    # that's settled — and merge rather than replace whatever is already allowed.
    initializer "agent_vm_tunnel.allow_action_cable_origins" do |app|
      app.config.after_initialize do
        config = AgentVmTunnel.configuration
        next unless config.applies_to?(Rails.env)
        next unless defined?(ActionCable) && ActionCable.server

        origins = config.allowed_origins
        next if origins.empty?

        cable = ActionCable.server.config
        cable.allowed_request_origins =
          (Array(cable.allowed_request_origins) + origins).uniq
      end
    end
  end
end
