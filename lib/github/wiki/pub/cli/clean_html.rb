# frozen_string_literal: true

require "fileutils"

module Github
  module Wiki
    module Pub
      module CLI
        # Cleans wiki HTML exports in place: admonitions, mermaid diagrams,
        # duplicated <h1> headers, and the page's font and layout.
        class CleanHtml < BaseCommand
          desc "Clean up wiki HTML exports: admonitions, mermaid diagrams, duplicate headers, font and layout"

          argument :files, type: :array, required: true, desc: "HTML files to clean"

          include CleanerOptions

          option :output, aliases: ["-o"], desc: "Write here instead of in place (one input file only)"
          option :backup, type: :boolean, default: false, aliases: ["-b"], desc: "Copy each file to FILE.bak before writing"
          option :dry_run, type: :boolean, default: false, aliases: ["-n"], desc: "Report what would change, write nothing"

          example [
            "wiki-app.html wiki-atlas.html",
            "wiki.html --page-width 90 --nav-width 25 --backup",
            "wiki.html -o clean.html --mermaid-version 11",
            "wiki.html --dry-run --no-styles"
          ]

          def call(files:, output: nil, dry_run: false, backup: false, **options)
            if output && files.size > 1
              ui.error "--output takes exactly one input file, got #{files.size}"
              exit 1
            elsif files.nil? || files.empty?
              ui.error "FILE argument is required, eg: " + Pastel.new.bold.yellow("#{::File.basename($PROGRAM_NAME)} clean-html document.html [ -o output.html ]")
              exit 2
            end

            Setup.new.call # runs the setup command.

            cleaner = html_cleaner(options)
            files.each { |path| clean_file(cleaner, path, output || path, dry_run:, backup:) }
          end

          private

          def clean_file(cleaner, path, target, dry_run:, backup:)
            raise Error, "no such file: #{path}" unless File.file?(path)

            result = cleaner.clean(File.read(path))
            summary = format_counts(result.counts)
            return out.puts("#{path}: would convert #{summary} (dry run)") if dry_run

            make_backup(target) if backup
            File.write(target, result.html)
            out.puts(target == path ? "#{path}: #{summary}" : "#{path} -> #{target}: #{summary}")
          end

          # An existing backup is the older original, so it is never overwritten.
          def make_backup(target)
            return unless File.exist?(target)

            backup = "#{target}.bak"
            if File.exist?(backup)
              err.puts "#{backup} already exists, keeping it"
            else
              FileUtils.cp(target, backup)
            end
          end
        end
      end
    end
  end
end
