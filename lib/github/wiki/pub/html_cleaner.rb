# frozen_string_literal: true

require "cgi"
require "json"
require "yaml"

module Github
  module Wiki
    module Pub
      # Polishes HTML exported from the wiki-gen markdown. Every step is
      # idempotent, so a file can be cleaned any number of times.
      #
      #   cleaner = HtmlCleaner.new(page_width: 95, nav_width: 20)
      #   result  = cleaner.clean(File.read("wiki.html"))
      #   result.html   # => the cleaned document
      #   result.counts # => { admonitions: 47, mermaid: 16, headers: 33 }
      class HtmlCleaner
        Result = Data.define(:html, :counts)

        DEFAULTS = {
          page_width: 95,
          nav_width: 20,
          content_padding: 30,
          font: "Nunito",
          mermaid_version: 9,
          admonitions: true,
          mermaid: true,
          dedupe_headers: true,
          styles: true
        }.freeze

        ADMONITIONS = {
          "NOTE" => ["fa-circle-info", "Note"],
          "TIP" => ["fa-lightbulb", "Tip"],
          "IMPORTANT" => ["fa-circle-exclamation", "Important"],
          "WARNING" => ["fa-triangle-exclamation", "Warning"],
          "CAUTION" => ["fa-circle-xmark", "Caution"]
        }.freeze

        ADMONITION_PATTERN = %r{<blockquote>\s*<p>\[!(#{ADMONITIONS.keys.join('|')})\]\s*(.*?)</blockquote>}m

        DIAGRAM_TYPES = /(?:graph|flowchart|sequenceDiagram|classDiagram|stateDiagram(?:-v2)?|erDiagram|gantt|pie|journey|
          gitGraph|mindmap|timeline|C4Context|C4Container|C4Component|C4Dynamic|C4Deployment|quadrantChart|
          requirementDiagram|sankey-beta|xychart-beta|block-beta)\b/x

        # A diagram, optionally preceded by %% directives or `---` front-matter.
        # A plain YAML block (front-matter with no diagram after it) does not match.
        MERMAID_START = /\A(?:---\n.*?\n---\n)?(?:\s*%%.*\n)*\s*#{DIAGRAM_TYPES}/m

        DUPLICATE_H1 = %r{(<p class="page" id="[^"]*"></p>)<h1>([^<]*)</h1>(\s*<!-- generated-by: bin/wiki-gen -->\s*<h1 id="[^"]*">)\2(</h1>)}

        HEAD_MARKER = "<!-- github-wiki-pub:head -->"
        SCRIPT_MARKER = "<!-- github-wiki-pub:mermaid -->"

        # Blocks injected by this tool, or by the wiki-html-polish.rb script it replaces.
        OLD_HEAD = %r{<!-- (?:github-wiki-pub|wiki-html-polish):head -->.*?</style>\n}m
        OLD_SCRIPT = %r{(?:#{Regexp.escape(SCRIPT_MARKER)}\n)?<script type="module">\s*import mermaid .*?</script>\n?}m

        attr_reader :options

        def initialize(**options)
          unknown = options.keys - DEFAULTS.keys
          raise ArgumentError, "unknown options: #{unknown.join(', ')}" if unknown.any?

          @options = DEFAULTS.merge(options)
          validate!
        end

        def clean(html)
          counts = { admonitions: 0, mermaid: 0, headers: 0 }
          html, counts[:admonitions] = convert_admonitions(html) if options[:admonitions]
          html, counts[:mermaid] = convert_mermaid(html) if options[:mermaid]
          html, counts[:headers] = remove_duplicate_headers(html) if options[:dedupe_headers]
          html = inject_styles(html) if options[:styles]
          html = inject_mermaid_script(html) if options[:mermaid] && html.include?('<pre class="mermaid">')
          Result.new(html:, counts:)
        end

        def convert_admonitions(html)
          count = 0
          html = html.gsub(ADMONITION_PATTERN) do
            count += 1
            kind = Regexp.last_match(1)
            icon, label = ADMONITIONS.fetch(kind)
            %(<div class="admonition admonition-#{kind.downcase}">\n) +
              %(<p class="admonition-title"><i class="fa-solid #{icon}"></i> #{label}</p>\n) +
              "<p>#{Regexp.last_match(2).strip}\n</div>"
          end
          [html, count]
        end

        # Code blocks lose their language tag on export and come out as
        # highlighted <pre class="hljs">, so diagrams are recognized by content.
        def convert_mermaid(html)
          count = 0
          html = html.gsub(%r{<pre class="hljs">(.*?)</pre>}m) do |block|
            text = CGI.unescapeHTML(Regexp.last_match(1).gsub(/<[^>]+>/, "")).sub(/\A\s*\n/, "").lstrip
            next block unless text.match?(MERMAID_START)

            count += 1
            body = mermaid_source(text).strip.lines.map { |line| "  #{line.chomp}" }.join("\n")
            %(<pre class="mermaid">\n#{CGI.escapeHTML(body)}\n</pre>)
          end
          [html, count]
        end

        def remove_duplicate_headers(html)
          count = 0
          html = html.gsub(DUPLICATE_H1) do
            count += 1
            match = Regexp.last_match
            "#{match[1]}#{match[3]}#{match[2]}#{match[4]}"
          end
          [html, count]
        end

        def inject_styles(html)
          html.sub(OLD_HEAD, "").sub("</head>", "#{head_assets}</head>")
        end

        def inject_mermaid_script(html)
          html = html.sub(OLD_SCRIPT, "").sub(/^#{Regexp.escape(SCRIPT_MARKER)}\n/, "")
          index = html.rindex("</body>")
          index ? html.insert(index, mermaid_script) : html + mermaid_script
        end

        def head_assets
          font = options[:font]
          <<~HTML
            #{HEAD_MARKER}
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=#{font.tr(' ', '+')}:ital,wght@0,400;0,600;0,700;1,400&display=swap">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css">
            <style>
            body, h1, h2, h3, h4, h5, h6, p, li, td, th, .toc { font-family: '#{font}', Helvetica, Arial, sans-serif !important; }
            .container { width: #{options[:page_width]}% !important; max-width: none !important; }
            /* The fixed .nav-inner sizes against the viewport, not its column:
               nav% of the page% viewport, minus the 15px gutter it starts after. */
            @media (min-width: 992px) {
              #documentation-container > .row > .col-md-3 { width: #{options[:nav_width]}%; }
              #documentation-container > .row > .col-md-9 { width: #{100 - options[:nav_width]}%; padding-left: #{options[:content_padding]}px; }
              .html-doc .nav-container > .nav-inner { width: calc(#{nav_viewport_width}vw - 15px) !important; min-width: 0 !important; }
            }
            .admonition { margin: 1em 0; padding: .6em 1em; border-left: 4px solid; border-radius: 4px; }
            .admonition p { margin: .3em 0; }
            .admonition-title { font-weight: bold; }
            .admonition-title i { margin-right: .35em; }
            .admonition-note { border-color: #0969da; background: #ddf4ff; } .admonition-note .admonition-title { color: #0969da; }
            .admonition-tip { border-color: #1a7f37; background: #dafbe1; } .admonition-tip .admonition-title { color: #1a7f37; }
            .admonition-important { border-color: #8250df; background: #fbefff; } .admonition-important .admonition-title { color: #8250df; }
            .admonition-warning { border-color: #9a6700; background: #fff8c5; } .admonition-warning .admonition-title { color: #9a6700; }
            .admonition-caution { border-color: #cf222e; background: #ffebe9; } .admonition-caution .admonition-title { color: #cf222e; }
            pre.mermaid { background: transparent; border: 0; text-align: center; }
            </style>
          HTML
        end

        def mermaid_script
          <<~HTML
            #{SCRIPT_MARKER}
            <script type="module">
              import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@#{options[:mermaid_version]}/dist/mermaid.esm.min.mjs';
              mermaid.initialize({ startOnLoad: true });
            </script>
          HTML
        end

        private

        def validate!
          { page_width: 1..100, nav_width: 1..99, content_padding: 0..500, mermaid_version: 9..99 }.each do |key, range|
            value = options[key]
            raise ArgumentError, "#{key} must be an integer in #{range}, got #{value.inspect}" unless value.is_a?(Integer) && range.cover?(value)
          end
          raise ArgumentError, "font must not be blank" if options[:font].to_s.strip.empty?
        end

        def nav_viewport_width
          (options[:nav_width] * options[:page_width] / 100.0).round(2).to_s.delete_suffix(".0")
        end

        # Mermaid 10+ reads `---` front-matter itself. Mermaid 9 does not, so its
        # config is rewritten as the equivalent %%{init: ...}%% directive.
        def mermaid_source(text)
          return text if options[:mermaid_version] >= 10

          front = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
          return text unless front

          meta = YAML.safe_load(front[1]) || {}
          lines = []
          lines << "%%{init: #{JSON.generate(meta['config'])}}%%" if meta["config"]
          lines << "%% title: #{meta['title']}" if meta["title"]
          (lines << front[2]).join("\n")
        end
      end
    end
  end
end
