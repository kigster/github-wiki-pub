# frozen_string_literal: true

module Github
  module Wiki
    module Pub
      module CLI
        # The HtmlCleaner flags, shared by every command that cleans HTML.
        module CleanerOptions
          def self.included(command)
            command.option :page_width, default: "95", aliases: ["-w"], desc: "Page width, in % of the browser"
            command.option :nav_width, default: "20", aliases: ["-N"], desc: "Navigation bar width, in % of the page"
            command.option :content_padding, default: "30", aliases: ["-p"], desc: "Left padding of the content pane, in px"
            command.option :font, default: "Nunito", aliases: ["-f"], desc: "Base font, loaded from Google Fonts"
            command.option :mermaid_version, default: "9", aliases: ["-m"], desc: "Major version of mermaid to load"
            command.option :admonitions, type: :boolean, default: true, desc: "Convert > [!NOTE] admonitions"
            command.option :mermaid, type: :boolean, default: true, desc: "Convert mermaid code blocks"
            command.option :dedupe_headers, type: :boolean, default: true, desc: "Remove duplicated <h1> headers"
            command.option :styles, type: :boolean, default: true, desc: "Inject font, layout and admonition styles"
          end

          private

          def html_cleaner(options)
            HtmlCleaner.new(
              page_width: Integer(options.fetch(:page_width)),
              nav_width: Integer(options.fetch(:nav_width)),
              content_padding: Integer(options.fetch(:content_padding)),
              mermaid_version: Integer(options.fetch(:mermaid_version)),
              font: options.fetch(:font),
              admonitions: options.fetch(:admonitions),
              mermaid: options.fetch(:mermaid),
              dedupe_headers: options.fetch(:dedupe_headers),
              styles: options.fetch(:styles)
            )
          end

          def format_counts(counts)
            "#{counts[:admonitions]} admonitions, #{counts[:mermaid]} mermaid diagrams, " \
              "#{counts[:headers]} duplicate headers removed"
          end
        end
      end
    end
  end
end
