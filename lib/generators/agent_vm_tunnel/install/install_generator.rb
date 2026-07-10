# frozen_string_literal: true

require "json"
require "agent_vm_tunnel/configuration"

module AgentVmTunnel
  module Generators
    # `rails g agent_vm_tunnel:install`
    #
    # Drops the shell half of the tunnel into the host app: the keep-alive
    # script, the cloud-environment setup script, and the selected providers'
    # lifecycle integration. The Rails config half is handled automatically by
    # the Railtie, so this generator never touches config/environments.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      # The public fingerprint of the default firstdraft.io tunnel. This remains
      # an independent pin: the coordinates endpoint may move the HTTPS URL but
      # is never allowed to replace the server key.
      FIRSTDRAFT_FINGERPRINT = "qiHyU1ZKorF5AHUy5GrhYSemXAGaFbIYb9a1wWvZxIk="

      class_option :host, type: :string, default: AgentVmTunnel::Configuration::DEFAULT_HOST,
        desc: "Tunnel base host (previews live at <name>.<host>)"
      class_option :fingerprint, type: :string, default: nil,
        desc: "Pinned chisel server fingerprint (required for a custom --host)"
      class_option :provider, type: :string, default: "claude",
        desc: "Cloud provider target: claude, codex, both, or generic"

      def validate_options
        unless host.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/) && !host.include?("..")
          raise Thor::Error, "--host must be a lowercase DNS name"
        end
        unless %w[claude codex both generic].include?(provider)
          raise Thor::Error, "--provider must be claude, codex, both, or generic"
        end
        unless fingerprint.match?(/\A[A-Za-z0-9+\/]{43}=\z/)
          raise Thor::Error, "--fingerprint is required for a custom host and must be a 44-character base64 chisel fingerprint"
        end
      end

      def create_project_config
        create_file "config/agent_vm_tunnel.json", JSON.pretty_generate({
          "host" => host,
          "fingerprint" => fingerprint,
          "provider" => provider
        }) + "\n", force: true
      end

      def create_connector_script
        template "agent-vm-tunnel.tt", "bin/agent-vm-tunnel"
        chmod "bin/agent-vm-tunnel", 0o755, verbose: false
      end

      def create_cloud_vm_setup_script
        template "cloud-vm-setup.sh.tt", "cloud-vm-setup.sh"
        chmod "cloud-vm-setup.sh", 0o755, verbose: false
      end

      def install_claude_hooks
        return unless %w[claude both].include?(provider)

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

      def install_codex_guidance
        return unless %w[codex both].include?(provider)

        rel = "AGENTS.md"
        abs = File.join(destination_root, rel)
        existing = File.exist?(abs) ? File.read(abs).rstrip : ""
        section = <<~MARKDOWN.rstrip
          <!-- agent-vm-tunnel:codex:start -->
          ## Live preview in Codex Cloud

          Before work that needs the running preview, run `bin/agent-vm-tunnel ensure`.
          Use `bin/agent-vm-tunnel status` to diagnose the app or tunnel, and read
          `tmp/agent-vm-tunnel/app.log` or `tmp/agent-vm-tunnel/tunnel.log` before
          changing configuration. Never commit `AGENT_VM_TUNNEL`; it belongs in the
          Codex Cloud environment variables.
          <!-- agent-vm-tunnel:codex:end -->
        MARKDOWN

        updated = if existing.include?("<!-- agent-vm-tunnel:codex:start -->")
          existing.sub(/<!-- agent-vm-tunnel:codex:start -->.*?<!-- agent-vm-tunnel:codex:end -->/m, section)
        else
          [existing, section].reject(&:empty?).join("\n\n")
        end
        create_file rel, updated + "\n", force: File.exist?(abs)
      end

      def print_next_steps
        say ""
        say "agent_vm_tunnel installed.", :green
        say <<~STEPS
          Next:
            1. Claim a slot at https://#{options[:host]} and copy the one
               AGENT_VM_TUNNEL=<slot>:<password> value it shows you.
            2. #{provider_setup_step}
            3. #{provider_next_step}

          Run bin/agent-vm-tunnel by hand any time to force a (re)start.
        STEPS
      end

      private

      def host
        options[:host]
      end

      def provider
        options[:provider]
      end

      def fingerprint
        return options[:fingerprint] if options[:fingerprint]
        (host == AgentVmTunnel::Configuration::DEFAULT_HOST) ? FIRSTDRAFT_FINGERPRINT : ""
      end

      def provider_next_step
        case provider
        when "claude"
          "Start a session. Project hooks run bin/agent-vm-tunnel ensure on session start and each prompt."
        when "codex"
          "Configure cloud-vm-setup.sh as the setup script and bin/agent-vm-tunnel ensure as the maintenance script."
        when "both"
          "Configure each provider separately: Claude uses the generated hooks; Codex uses the setup and maintenance fields."
        else
          "Run cloud-vm-setup.sh once, then run bin/agent-vm-tunnel ensure whenever the environment resumes."
        end
      end

      def provider_setup_step
        case provider
        when "claude"
          "In Claude Cloud, use cloud-vm-setup.sh as setup, paste the environment variable, and select Full network access."
        when "codex"
          "In Codex Cloud, use cloud-vm-setup.sh as setup, bin/agent-vm-tunnel ensure as maintenance, and add the environment variable."
        when "both"
          "Configure both environments; use separate preview credentials if they may run at the same time."
        else
          "Run cloud-vm-setup.sh in the target Linux environment and add the environment variable."
        end
      end

      # Ensure a SessionStart and UserPromptSubmit hook each run bin/agent-vm-tunnel,
      # without disturbing any hooks the app already has. Returns the list of
      # events we actually added.
      def add_preview_hooks(settings)
        hooks = (settings["hooks"] ||= {})
        %w[SessionStart UserPromptSubmit].each_with_object([]) do |event, added|
          groups = (hooks[event] ||= [])
          next if runs_preview?(groups)
          groups << {"hooks" => [{"type" => "command", "command" => "bin/agent-vm-tunnel ensure", "timeout" => 60}]}
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
