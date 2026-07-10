# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "json"
require "open3"
require "socket"
require "tmpdir"
require "rails/generators"
require "generators/agent_vm_tunnel/install/install_generator"

class ConnectorRuntimeTest < Minitest::Test
  FINGERPRINT = ("A" * 43) + "="

  def setup
    @root = Dir.mktmpdir("agent-vm-tunnel-runtime")
    AgentVmTunnel::Generators::InstallGenerator.start(
      ["--provider=generic", "--fingerprint=#{FINGERPRINT}"],
      destination_root: @root,
      behavior: :invoke,
      quiet: true
    )
    File.write(File.join(@root, ".ruby-version"), RUBY_VERSION)
    FileUtils.mkdir_p(File.join(@root, "config"))
    File.write(File.join(@root, "config/database.yml"), "development:\n  adapter: sqlite3\n")
    @app_port = available_port
    install_fakes
  end

  def teardown
    run_connector("stop") if @root && File.exist?(connector)
    FileUtils.remove_entry(@root) if @root && File.exist?(@root)
  end

  def test_repeated_and_concurrent_ensures_start_one_owned_process_each
    results = 2.times.map { Thread.new { run_connector("ensure", "AGENT_VM_TUNNEL" => "7:secret") } }.map(&:value)
    results.each { |stdout, stderr, status| assert status.success?, "#{stdout}\n#{stderr}" }

    assert_equal [@app_port.to_s], lines("app-ports")
    assert_equal 1, lines("chisel-starts").length

    _stdout, stderr, status = run_connector("ensure", "AGENT_VM_TUNNEL" => "7:secret")
    assert status.success?, stderr
    assert_equal 1, lines("chisel-starts").length
  end

  def test_credential_change_restarts_tunnel_and_removal_stops_it
    assert run_connector("ensure", "AGENT_VM_TUNNEL" => "7:first").last.success?
    first_pid = runtime_file("tunnel.pid").read.to_i

    assert run_connector("ensure", "AGENT_VM_TUNNEL" => "7:second").last.success?
    second_pid = runtime_file("tunnel.pid").read.to_i
    refute_equal first_pid, second_pid
    assert_equal 2, lines("chisel-starts").length

    _stdout, stderr, status = run_connector("ensure", "AGENT_VM_TUNNEL" => nil)
    assert status.success?, stderr
    refute runtime_file("tunnel.pid").exist?
    assert runtime_file("app.pid").exist?, "removing the credential should not kill the app"
  end

  def test_app_port_is_passed_as_port_and_secret_is_scrubbed_from_app
    _stdout, stderr, status = run_connector("ensure", "AGENT_VM_TUNNEL" => "9:top-secret")
    assert status.success?, stderr
    assert_equal [@app_port.to_s], lines("app-ports")
    assert_equal ["unset"], lines("app-secrets")
    assert_equal ["slot9:top-secret"], lines("chisel-auth")
  end

  def test_malicious_coordinates_are_rejected_without_shell_evaluation
    marker = File.join(@root, "injected")
    payload = {connect_url: "https://tunnel.firstdraft.io/'; touch #{marker}; #", fingerprint: "B" * 43 + "="}.to_json
    _stdout, stderr, status = run_connector("ensure", "AGENT_VM_TUNNEL" => "4:safe", "FAKE_COORDINATES" => payload)
    assert status.success?, stderr
    refute File.exist?(marker)
    assert_includes lines("chisel-args"), "https://tunnel.firstdraft.io"
    assert_includes lines("chisel-args"), FINGERPRINT
    refute_includes lines("chisel-args"), "B" * 43 + "="
  end

  private

  def available_port
    socket = TCPServer.new("127.0.0.1", 0)
    socket.addr[1]
  ensure
    socket&.close
  end

  def connector
    File.join(@root, "bin/agent-vm-tunnel")
  end

  def runtime_file(name)
    Pathname.new(File.join(@root, "tmp/agent-vm-tunnel", name))
  end

  def lines(name)
    path = File.join(@root, "tmp", name)
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  def run_connector(action, extra_env = {})
    env = {
      "PATH" => "#{File.join(@root, "fake-bin")}:#{ENV.fetch("PATH")}",
      "APP_PORT" => @app_port.to_s,
      "TEST_ROOT" => @root,
      "FAKE_COORDINATES" => {connect_url: "https://tunnel.firstdraft.io", fingerprint: "ignored"}.to_json,
      "HTTPS_PROXY" => nil,
      "https_proxy" => nil,
      "CHISEL_CA" => nil
    }.merge(extra_env)
    Open3.capture3(env, connector, action, chdir: @root)
  end

  def install_fakes
    fake_bin = File.join(@root, "fake-bin")
    FileUtils.mkdir_p(fake_bin)
    write_executable(File.join(fake_bin, "curl"), <<~BASH)
      #!/usr/bin/env bash
      printf '%s' "$FAKE_COORDINATES"
    BASH
    write_executable(File.join(fake_bin, "chisel"), <<~BASH)
      #!/usr/bin/env bash
      printf '%s\n' "$AUTH" >>"$TEST_ROOT/tmp/chisel-auth"
      printf '%s\n' "$$" >>"$TEST_ROOT/tmp/chisel-starts"
      printf '%s\n' "$@" >>"$TEST_ROOT/tmp/chisel-args"
      trap 'exit 0' TERM INT
      while :; do sleep 1; done
    BASH
    write_executable(File.join(@root, "bin/dev"), <<~BASH)
      #!/usr/bin/env bash
      printf '%s\n' "$PORT" >>"$TEST_ROOT/tmp/app-ports"
      printf '%s\n' "${AGENT_VM_TUNNEL:-unset}" >>"$TEST_ROOT/tmp/app-secrets"
      exec ruby -rsocket -e '
        server = TCPServer.new("127.0.0.1", Integer(ENV.fetch("PORT")))
        trap("TERM") { exit }
        loop { client = server.accept; client.close }
      '
    BASH
  end

  def write_executable(path, content)
    File.write(path, content)
    FileUtils.chmod(0o755, path)
  end
end
