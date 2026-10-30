# frozen_string_literal: true

require "fileutils"
require "tty-command"

module Github
  module Wiki
    module Pub
      # Runs gwtc, the github-wikito-converter npm package, which renders a
      # markdown wiki directory into one HTML document.
      #
      #   Gwtc.new.to_html("wiki", "docs/wiki.html", title: "Acme")
      class Gwtc
        PACKAGE = "github-wikito-converter"
        INSTALL_HINT = "install it with: npm install -g #{PACKAGE}".freeze

        # Our option name => gwtc's flag. Booleans are passed bare, when true.
        FLAGS = {
          title: "--title",
          disable_inline_assets: "--disable-inline-assets",
          logo_img: "--logo-img",
          footer: "--footer",
          toc: "--toc",
          toc_title: "--toctitle",
          toc_level: "--toc-level",
          highlight_theme: "--highlight-theme",
          css: "--css",
          verbose: "--verbose"
        }.freeze

        attr_reader :executable

        # GWTC overrides which executable runs, for a pinned install or for tests.
        def initialize(executable: ENV.fetch("GWTC", "gwtc"), runner: nil)
          @executable = executable
          @runner = runner
        end

        def available?
          !path.nil?
        end

        # The full command line, for --dry-run and for the log.
        def command(wiki_dir, output, **options)
          [
            executable, File.expand_path(wiki_dir),
            "--format", "html",
            "--output", File.dirname(File.expand_path(output)),
            "--file-name", File.basename(output, ".html"),
            *flags(options)
          ]
        end

        def to_html(wiki_dir, output, **options)
          raise Error, "no such wiki directory: #{wiki_dir}" unless File.directory?(wiki_dir)
          raise Error, "#{executable} not found; #{INSTALL_HINT}" unless available?
          raise Error, "--output must end in .html, got #{output}" unless output.end_with?(".html")

          # gwtc writes nothing, and still exits 0, when the directory is missing.
          FileUtils.mkdir_p(File.dirname(File.expand_path(output)))
          runner(options[:verbose]).run(*command(wiki_dir, output, **options))
          raise Error, "#{executable} finished but wrote no #{output}" unless File.file?(output)

          output
        end

        private

        def flags(options)
          options.flat_map do |key, value|
            flag = FLAGS.fetch(key) { raise ArgumentError, "unknown gwtc option: #{key}" }
            case value
            when true then [flag]
            when false, nil then []
            else [flag, value.to_s]
            end
          end
        end

        def path
          return executable if executable.include?(File::SEPARATOR) && File.executable?(executable)

          ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
             .map { |dir| File.join(dir, executable) }
             .find { |candidate| File.file?(candidate) && File.executable?(candidate) }
        end

        # gwtc prints deprecation noise on stderr, so it is shown only with --verbose.
        def runner(verbose)
          @runner || TTY::Command.new(printer: verbose ? :pretty : :null, output: $stderr)
        end
      end
    end
  end
end
