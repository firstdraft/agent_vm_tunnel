# frozen_string_literal: true

require_relative "lib/agent_vm_tunnel/version"

Gem::Specification.new do |spec|
  spec.name = "agent_vm_tunnel"
  spec.version = AgentVmTunnel::VERSION
  spec.authors = ["Raghu Betina"]
  spec.email = ["raghu@firstdraft.com"]

  spec.summary = "Public Rails preview URLs for Codex, Claude, and outbound-only cloud environments."
  spec.description = <<~DESC
    Cloud development containers often cannot accept inbound connections, so
    their Rails servers are not directly accessible from a browser.
    agent_vm_tunnel exposes an app through a pinned chisel reverse tunnel at an
    opaque public HTTPS URL. Its Railtie configures Rails host authorization
    while retaining exact same-origin Action Cable protection. Its generator
    installs provider-aware setup and lifecycle scripts for Codex Cloud,
    Claude cloud environments, or a generic Linux sandbox.
  DESC
  spec.homepage = "https://github.com/firstdraft/agent_vm_tunnel"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://firstdraft.github.io/agent_vm_tunnel/"
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
