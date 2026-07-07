# frozen_string_literal: true

require "test_helper"
require "action_controller/railtie"
require "action_cable/engine"
require "rack/mock"
# test_helper requires agent_vm_tunnel before Rails is loaded, so its
# `if defined?(Rails::Railtie)` guard skips the railtie. Now that Rails is
# loaded, force it in. (A real app loads gems after Rails, so the guard fires
# there without help.)
require "agent_vm_tunnel/railtie"

# Boots a real (minimal) Rails application so we exercise the actual initializer
# ordering, not a stub. Rails.application is a process-global singleton that can
# only be initialized once, so the app is defined and booted a single time here
# and the test methods assert against the result.
class RailtieTest < Minitest::Test
  class TestApp < Rails::Application
    config.eager_load = false
    config.consider_all_requests_local = true
    config.secret_key_base = "test-secret"
    config.logger = Logger.new(IO::NULL)
  end

  TestApp.initialize!
  TestApp.routes.draw do
    get "/up", to: ->(_env) { [200, {"content-type" => "text/plain"}, ["ok"]] }
  end

  def test_allows_the_tunnel_wildcard_host
    assert_includes TestApp.config.hosts, ".firstdraft.io"
  end

  # The real end-to-end proof: a request whose Host is a tunnel preview subdomain
  # passes through the actual HostAuthorization middleware instead of getting the
  # "Blocked hosts" 403.
  def test_tunnel_host_passes_host_authorization
    res = Rack::MockRequest.new(TestApp).get("/up", "HTTP_HOST" => "ada.firstdraft.io")
    assert_equal 200, res.status, res.body
  end

  def test_unrelated_host_is_still_blocked
    res = Rack::MockRequest.new(TestApp).get("/up", "HTTP_HOST" => "evil.example.com")
    assert_equal 403, res.status
  end

  def test_registers_action_cable_origins_on_the_server
    origins = ActionCable.server.config.allowed_request_origins
    assert origins.any? { |o| o.is_a?(Regexp) && o.match?("https://ada.firstdraft.io") },
      "expected an allowed origin matching a preview subdomain, got #{origins.inspect}"
  end

  def test_does_not_double_register_the_host
    assert_equal 1, TestApp.config.hosts.count(".firstdraft.io")
  end
end
