# frozen_string_literal: true

require_relative "lib/agent_vm_tunnel/version"

Gem::Specification.new do |spec|
  spec.name = "agent_vm_tunnel"
  spec.version = AgentVmTunnel::VERSION
  spec.authors = ["Raghu Betina"]
  spec.email = ["raghu@firstdraft.com"]

  spec.summary = "Public live-preview URLs for Rails apps built in Claude Cloud VMs, over a chisel reverse tunnel."
  spec.description = <<~DESC
    Claude Cloud VMs (and similar sandboxes) can't accept inbound connections,
    so you can't just open the Rails server you're building in a browser.
    agent_vm_tunnel exposes it at a public https://<name>.firstdraft.io URL
    through a self-hosted chisel reverse tunnel. Add the gem and run
    `rails g agent_vm_tunnel:install`: a Railtie allows the tunnel hosts and
    Action Cable origins automatically, and the generator drops in the
    keep-alive script and Claude Code hooks that bring the app + tunnel up on
    every turn. Point it at the default firstdraft.io tunnel or your own box.
  DESC
  spec.homepage = "https://github.com/firstdraft/agent_vm_tunnel"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
