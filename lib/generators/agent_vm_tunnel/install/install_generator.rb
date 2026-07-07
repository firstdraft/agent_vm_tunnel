# frozen_string_literal: true

require "json"
require "agent_vm_tunnel/configuration"

module AgentVmTunnel
  module Generators
    # `rails g agent_vm_tunnel:install`
    #
    # Drops the shell half of the tunnel into the host app: the keep-alive
    # script (bin/agent-vm-tunnel), the Cloud VM setup script, and the Claude Code hooks
    # that run the keep-alive on every turn. The Rails config half is handled
    # automatically by the Railtie, so this generator never touches
    # config/environments.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      # The public fingerprint of the default firstdraft.io tunnel. Baked in as a
      # fallback so the very first connect works even if the coordinates
      # endpoint is briefly unreachable; bin/agent-vm-tunnel refreshes it from
      # https://<host>/tunnel on each (re)start.
      FIRSTDRAFT_FINGERPRINT = "qiHyU1ZKorF5AHUy5GrhYSemXAGaFbIYb9a1wWvZxIk="

      class_option :host, type: :string, default: AgentVmTunnel::Configuration::DEFAULT_HOST,
        desc: "Tunnel base host (previews live at <name>.<host>)"
      class_option :fingerprint, type: :string, default: nil,
        desc: "chisel server fingerprint fallback (defaults to the firstdraft.io tunnel's when --host is firstdraft.io)"

      def create_connector_script
        template "agent-vm-tunnel.tt", "bin/agent-vm-tunnel"
        chmod "bin/agent-vm-tunnel", 0o755, verbose: false
      end

      def create_cloud_vm_setup_script
        template "cloud-vm-setup.sh.tt", "cloud-vm-setup.sh"
        chmod "cloud-vm-setup.sh", 0o755, verbose: false
      end

      def install_claude_hooks
        rel = ".claude/settings.json"
        abs = File.join(destination_root, rel)
        settings = File.exist?(abs) ? JSON.parse(File.read(abs)) : {}
        added = add_preview_hooks(settings)

        if added.empty?
          say_status :identical, rel, :blue
        else
          empty_directory ".claude" unless File.directory?(File.join(destination_root, ".claude"))
          create_file rel, JSON.pretty_generate(settings) + "\n", force: true
          say_status :hooks, "added #{added.join(" + ")} → bin/agent-vm-tunnel", :green
        end
      end

      def print_next_steps
        say ""
        say "agent_vm_tunnel installed.", :green
        say <<~STEPS
          Next:
            1. Claim a slot at https://#{options[:host]} and copy the one
               AGENT_VM_TUNNEL=<slot>:<password> value it shows you.
            2. In your Claude Cloud VM (claude.ai/code → Add cloud environment):
               • Setup script → point it at this repo's cloud-vm-setup.sh
               • Environment variables → paste the AGENT_VM_TUNNEL value
               • Network access → Full (the tunnel needs unrestricted egress)
            3. Start a session. The Claude Code hooks run bin/agent-vm-tunnel on every
               turn, so the app + tunnel come up (and self-heal) automatically.
               Open https://<your-github-login>.#{options[:host]}.

          Run bin/agent-vm-tunnel by hand any time to force a (re)start.
        STEPS
      end

      private

      def host
        options[:host]
      end

      def fingerprint
        return options[:fingerprint] if options[:fingerprint]
        (host == AgentVmTunnel::Configuration::DEFAULT_HOST) ? FIRSTDRAFT_FINGERPRINT : ""
      end

      # Ensure a SessionStart and UserPromptSubmit hook each run bin/agent-vm-tunnel,
      # without disturbing any hooks the app already has. Returns the list of
      # events we actually added.
      def add_preview_hooks(settings)
        hooks = (settings["hooks"] ||= {})
        %w[SessionStart UserPromptSubmit].each_with_object([]) do |event, added|
          groups = (hooks[event] ||= [])
          next if runs_preview?(groups)
          groups << {"hooks" => [{"type" => "command", "command" => "bin/agent-vm-tunnel", "timeout" => 60}]}
          added << event
        end
      end

      def runs_preview?(groups)
        groups.any? do |group|
          Array(group["hooks"]).any? { |h| h["command"].to_s.include?("bin/agent-vm-tunnel") }
        end
      end
    end
  end
end
