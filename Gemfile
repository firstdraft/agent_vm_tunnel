# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in agent_vm_tunnel.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

gem "minitest", "~> 5.16"

gem "standard", "~> 1.3"
# standard -> rubocop -> parallel; parallel 2.x requires Ruby >= 3.3, which
# breaks `bundle install` on the 3.2 CI leg. Pin to the 3.2-compatible line so
# the gem's stated Ruby floor stays genuinely tested.
gem "parallel", "~> 1.26"

# The Railtie only needs railties (the runtime dependency), but the integration
# test boots a real app that exercises host authorization and Action Cable.
group :test do
  gem "actionpack"
  gem "actioncable"
end
