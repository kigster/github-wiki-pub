# frozen_string_literal: true

module Github
  module Wiki
    module Pub
      module CLI
        module Wiki
          # Renders a markdown wiki into one HTML document with gwtc, then
          # cleans it the way clean-html does.
          class ToHtml < Command
            desc "Render a markdown wiki directory into one HTML document (via gwtc), then clean it"

            argument :wiki_dir, required: true, desc: "Directory holding the wiki's .md files"

            option :output, default: "documentation.html", aliases: ["-o"], desc: "HTML file to write"
            option :title, default: "Documentation", aliases: ["-t"], desc: "Wiki title"
            option :toc, desc: "Markdown file to use as the table of contents (gwtc defaults to _Sidebar.md)"
            option :toc_title, default: "Table of contents", desc: "Title of the table of contents"
            option :toc_level, default: "3", desc: "Deepest heading level in the table of contents"
            option :footer, desc: "Wiki footer"
            option :logo_img, desc: "Logo image file"
            option :css, desc: "Additional CSS file"
            option :highlight_theme, default: "github", desc: "highlight.js theme for code blocks"
            option :disable_inline_assets, type: :boolean, default: false, aliases: ["-d"],
                                           desc: "Link CSS and JS instead of inlining them"
            option :clean, type: :boolean, default: true, desc: "Clean the result, as clean-html does"
            option :dry_run, type: :boolean, default: false, aliases: ["-n"], desc: "Print the gwtc command, write nothing"

            include CleanerOptions

            example [
              "wiki -o docs/wiki-app.html -t 'Example App'",
              "wiki -o wiki.html --toc wiki/_Sidebar.md --toc-level 2",
              "wiki -o wiki.html --no-clean",
              "wiki -o wiki.html --nav-width 25 --mermaid-version 11"
            ]

            GWTC_OPTIONS = %i[title toc toc_title toc_level footer logo_img css highlight_theme disable_inline_assets].freeze

            def call(wiki_dir:, output:, clean:, dry_run:, verbose: false, **options)
              gwtc = Gwtc.new
              gwtc_options = options.slice(*GWTC_OPTIONS).merge(toc_level: Integer(options.fetch(:toc_level)), verbose:)
              cleaner = html_cleaner(options) if clean
              return out.puts(Shellwords.join(gwtc.command(wiki_dir, output, **gwtc_options))) if dry_run

              gwtc.to_html(wiki_dir, output, **gwtc_options)
              return out.puts("#{wiki_dir} -> #{output}") unless cleaner

              result = cleaner.clean(File.read(output))
              File.write(output, result.html)
              out.puts("#{wiki_dir} -> #{output}: #{format_counts(result.counts)}")
            end
          end
        end
      end
    end
  end
end
