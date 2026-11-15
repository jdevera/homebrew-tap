# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "../scripts/update_readme"

class ReadmeGeneratorTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    @readme = "# My tap\n\n#{ReadmeGenerator::START_MARKER}\nold content\n" \
              "#{ReadmeGenerator::END_MARKER}\n\nHand-written instructions.\n"
    File.write(File.join(@root, "README.md"), @readme)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def package(path, body, cask: false)
    full_path = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    definition = cask ? 'cask "example" do' : "class Example < Formula"
    File.write(full_path, "#{definition}\n#{body}\nend\n")
    full_path
  end

  def test_discovers_both_formula_locations_and_nested_casks
    fields = "  desc 'An example'\n  homepage 'https://example.com'"
    package("zebra.rb", fields)
    package("Formula/a/alpha.rb", fields)
    package("Casks/a/app.rb", fields, cask: true)
    package("scripts/ignored.rb", fields)

    rendered = ReadmeGenerator.render(@readme, root: @root)
    assert_includes rendered, "brew install jdevera/tap/zebra"
    assert_includes rendered, "brew install jdevera/tap/alpha"
    assert_includes rendered, "brew install --cask jdevera/tap/app"
    assert_includes rendered, "See [app](https://example.com) for documentation."
    assert_operator rendered.index("### alpha"), :<, rendered.index("### zebra")
    refute_includes rendered, "ignored"
    assert rendered.start_with?("# My tap\n\n#{ReadmeGenerator::START_MARKER}")
    assert rendered.end_with?("#{ReadmeGenerator::END_MARKER}\n\nHand-written instructions.\n")
    assert_equal rendered, ReadmeGenerator.render(rendered, root: @root)
  end

  def test_metadata_changes_and_package_removal_replace_old_entries
    path = package("example.rb", "  desc 'Old description'\n  homepage 'https://old.example.com'")
    previous = ReadmeGenerator.render(@readme, root: @root)
    package("example.rb", "  desc 'New description'\n  homepage 'https://new.example.com'")

    updated = ReadmeGenerator.render(previous, root: @root)
    assert_includes updated, "New description"
    assert_includes updated, "https://new.example.com"
    refute_includes updated, "Old description"
    refute_includes updated, "https://old.example.com"

    File.delete(path)
    removed = ReadmeGenerator.render(updated, root: @root)
    refute_includes removed, "### example"
    refute_includes removed, "## Formulae"
  end

  def test_reads_literal_metadata_without_executing_package_code
    path = package("example.rb", <<~'RUBY')
      raise "Package code must not run"
      resource "dependency" do
        desc "Ignore nested metadata"
      end
      desc "A \"quoted\" description"
      homepage 'https://example.com'
    RUBY

    assert_equal ['A "quoted" description', "https://example.com"],
                 ReadmeGenerator.metadata(path, cask: false)
  end

  def test_rejects_missing_dynamic_and_invalid_metadata
    ["homepage 'https://example.com'", 'desc "#{raise "must not run"}"',
     "desc ENV.fetch('DESCRIPTION')", "desc ''", "not valid Ruby !!!"].each do |body|
      path = package("example.rb", body)
      assert_raises(RuntimeError) { ReadmeGenerator.metadata(path, cask: false) }
    end
  end

  def test_preserves_unicode_and_decodes_single_quoted_escapes
    path = package("example.rb", <<~'RUBY')
      desc "Café \u2603"
      homepage 'https://example.com/it\'s'
    RUBY
    assert_equal ["Café ☃", "https://example.com/it's"],
                 ReadmeGenerator.metadata(path, cask: false)
  end

  def test_rejects_missing_duplicate_and_reversed_markers
    start_marker = ReadmeGenerator::START_MARKER
    end_marker = ReadmeGenerator::END_MARKER
    ["", start_marker, end_marker, "#{end_marker}\n#{start_marker}",
     "#{start_marker}\n#{start_marker}\n#{end_marker}",
     "#{start_marker}\n#{end_marker}\n#{end_marker}"].each do |readme|
      assert_raises(RuntimeError) { ReadmeGenerator.render(readme, root: @root) }
    end
  end

  def test_check_does_not_write_and_generation_is_repeatable
    package("example.rb", "  desc 'An example'\n  homepage 'https://example.com'")
    capture_io do
      assert_equal 1, ReadmeGenerator.run(["--check"], root: @root)
      assert_equal @readme, File.read(File.join(@root, "README.md"))
      assert_equal 0, ReadmeGenerator.run([], root: @root)
      generated = File.read(File.join(@root, "README.md"))
      assert_includes generated, "brew install jdevera/tap/example"
      assert_equal 0, ReadmeGenerator.run(["--check"], root: @root)
      assert_equal 0, ReadmeGenerator.run([], root: @root)
      assert_equal generated, File.read(File.join(@root, "README.md"))
    end
  end

  def test_invalid_metadata_leaves_readme_intact
    package("example.rb", "desc ENV.fetch('DESCRIPTION')")
    capture_io { assert_equal 1, ReadmeGenerator.run([], root: @root) }
    assert_equal @readme, File.read(File.join(@root, "README.md"))
  end
end
