# frozen_string_literal: true

require "optparse"
require "ripper"

module ReadmeGenerator
  ROOT = File.expand_path("..", __dir__)
  START_MARKER = "<!-- BEGIN GENERATED PACKAGES -->"
  END_MARKER = "<!-- END GENERATED PACKAGES -->"

  def self.metadata(path, cask:)
    source = File.read(path, encoding: "UTF-8")
    syntax = Ripper.sexp(source)
    raise "#{path}: invalid Ruby syntax" unless syntax

    definition = syntax[1].find do |node|
      if cask
        node[0] == :method_add_block && node.dig(1, 1, 1) == "cask"
      else
        node[0] == :class && node.dig(2, 1, 1) == "Formula"
      end
    end
    raise "#{path}: package definition not found" unless definition

    statements = cask ? definition.dig(2, 2, 1) : definition.dig(3, 1)
    %w[desc homepage].map do |field|
      command = statements.find { |node| node[0] == :command && node.dig(1, 1) == field }
      argument = command&.dig(2, 1, 0)
      parts = argument&.first == :string_literal ? argument[1].drop(1) : []
      unless !parts.empty? && parts.all? { |part| part[0] == :@tstring_content }
        raise "#{path}: #{field} must be a non-empty, literal string"
      end

      line, column = parts.first[2]
      quote = source.lines[line - 1].byteslice(column - 1, 1)
      value = parts.map { |part| part[1] }.join
      case quote
      when '"'
        ascii = value.gsub(/[^\x00-\x7f]/) { |character| character.dump[1...-1] }
        %Q("#{ascii}").undump
      when "'" then value.gsub(/\\(['\\])/, '\1')
      else raise "#{path}: #{field} must use a single- or double-quoted string"
      end
    end
  end

  def self.catalog(root)
    groups = {
      "Formulae" => Dir.glob(File.join(root, "{*,Formula/**/*}.rb")),
      "Casks" => Dir.glob(File.join(root, "Casks/**/*.rb"))
    }
    groups.map do |heading, paths|
      next if paths.empty?

      entries = paths.sort_by { |path| File.basename(path) }.map do |path|
        name = File.basename(path, ".rb")
        cask = heading == "Casks"
        description, homepage = metadata(path, cask: cask)
        <<~MARKDOWN.chomp
          ### #{name}

          #{description}

          ```bash
          brew install #{cask ? "--cask " : ""}jdevera/tap/#{name}
          ```

          See [#{name}](#{homepage}) for documentation.
        MARKDOWN
      end
      "## #{heading}\n\n#{entries.join("\n\n")}"
    end.compact.join("\n\n")
  end

  def self.render(readme, root: ROOT)
    unless readme.scan(START_MARKER).length == 1 && readme.scan(END_MARKER).length == 1 &&
           readme.index(START_MARKER) < readme.index(END_MARKER)
      raise "README.md must contain exactly one ordered pair of generated package markers"
    end

    pattern = /#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m
    readme.sub(pattern) { "#{START_MARKER}\n\n#{catalog(root)}\n\n#{END_MARKER}" }
  end

  def self.run(arguments, root: ROOT)
    check = false
    OptionParser.new do |options|
      options.banner = "Usage: ruby scripts/update_readme.rb [--check]"
      options.on("--check", "Fail if the README package list is out of date") { check = true }
    end.parse!(arguments)
    raise "Unexpected arguments: #{arguments.join(' ')}" unless arguments.empty?

    path = File.join(root, "README.md")
    current = File.read(path, encoding: "UTF-8")
    updated = render(current, root: root)
    return 0 if current == updated

    if check
      warn "README.md is out of date. Run: ruby scripts/update_readme.rb"
      return 1
    end

    File.write(path, updated)
    puts "Updated README.md"
    0
  rescue RuntimeError, ArgumentError, OptionParser::ParseError => error
    warn error.message
    1
  end
end

exit ReadmeGenerator.run(ARGV) if $PROGRAM_NAME == __FILE__
