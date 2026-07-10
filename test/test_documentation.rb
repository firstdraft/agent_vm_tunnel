# frozen_string_literal: true

require "test_helper"
require "pathname"

class DocumentationTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path

  def test_relative_markdown_links_resolve
    markdown_files.each do |source|
      source.read.scan(/\]\(([^)]+)\)/).flatten.each do |raw_target|
        target = raw_target.split(/[?#]/, 2).first
        next if target.empty? || target.match?(%r{\A(?:https?://|mailto:)})

        resolved = source.dirname.join(target).cleanpath
        assert resolved.exist?, "#{source.relative_path_from(ROOT)} links to missing #{target}"
      end
    end
  end

  def test_docs_do_not_describe_identity_bearing_preview_hosts
    text = markdown_files.map(&:read).join("\n")
    refute_includes text, "<you>-<app>"
    refute_includes text, "it's your username"
  end

  private

  def markdown_files
    [ROOT.join("README.md"), *ROOT.join("docs").glob("**/*.md")]
  end
end
