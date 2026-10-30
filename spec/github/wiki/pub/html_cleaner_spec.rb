# frozen_string_literal: true

RSpec.describe Github::Wiki::Pub::HtmlCleaner do
  subject(:result) { cleaner.clean(WikiHtml::DOCUMENT) }

  let(:cleaner) { described_class.new(**options) }
  let(:options) { {} }
  let(:html) { result.html }

  its(:counts) { is_expected.to eq(admonitions: 2, mermaid: 2, headers: 1) }

  describe "admonitions" do
    it "turns each admonition into a colored callout with an icon" do
      expect(html).to include('<div class="admonition admonition-note">')
        .and include('<i class="fa-solid fa-circle-info"></i> Note')
        .and include('<i class="fa-solid fa-circle-xmark"></i> Caution')
    end

    it "keeps the admonition's content" do
      expect(html).to include("<strong>Generated page</strong> — do not edit.</p>")
    end

    it "leaves ordinary quotes alone" do
      expect(html).to include("<blockquote>\n<p>An ordinary quote.</p>")
    end

    it "leaves no [!TYPE] markers behind" do
      expect(html).not_to match(/\[!(NOTE|CAUTION)\]/)
    end
  end

  describe "mermaid" do
    it "converts a highlighted diagram into a mermaid block, unescaped once" do
      expect(html).to include(%(<pre class="mermaid">\n  flowchart LR\n      A --&gt; B\n</pre>))
    end

    it "rewrites front-matter as an init directive for mermaid 9" do
      expect(html).to include("%%{init: {&quot;theme&quot;:&quot;base&quot;}}%%\n  %% title: Deploy\n  flowchart TD")
    end

    it "leaves YAML blocks that are not diagrams alone" do
      expect(html).to include(%(<pre class="hljs">---\nname: skill-name\n---</pre>))
    end

    it "leaves ordinary code alone" do
      expect(html).to include(%(<pre class="hljs">puts "hello"</pre>))
    end

    it "loads mermaid 9 once, before </body>", :aggregate_failures do
      expect(html.scan("mermaid@9/dist").size).to eq(1)
      expect(html).to match(%r{mermaid\.initialize.*</script>\n</body>}m)
    end

    context "with mermaid 11" do
      let(:options) { { mermaid_version: 11 } }

      it "keeps the front-matter, which mermaid 11 reads itself" do
        expect(html).to include("  ---\n  config:\n    theme: &#39;base&#39;\n  title: Deploy\n  ---")
      end

      it "loads mermaid 11" do
        expect(html).to include("mermaid@11/dist")
      end
    end

    context "when the document has no diagrams" do
      subject(:result) { cleaner.clean("<html><head></head><body></body></html>") }

      it "does not load mermaid" do
        expect(html).not_to include("mermaid.initialize")
      end
    end

    context "without </body>" do
      subject(:result) { cleaner.clean(%(<pre class="hljs">graph TD\n  A</pre>)) }

      it "appends the script" do
        expect(html).to end_with("</script>\n")
      end
    end
  end

  describe "duplicate headers" do
    it "drops the <h1> without an id and keeps the page anchor", :aggregate_failures do
      expect(html).to include(%(<p class="page" id="Home"></p>\n<!-- generated-by: bin/wiki-gen -->\n<h1 id="home">Home</h1>))
      expect(html).not_to include("<h1>Home</h1>")
    end
  end

  describe "styles" do
    it "loads the font and Font Awesome" do
      expect(html).to include("family=Nunito:").and include("font-awesome/6.5.2")
    end

    it "sizes the page, navigation and content" do
      expect(html).to include(".container { width: 95% !important;")
        .and include(".col-md-3 { width: 20%; }")
        .and include(".col-md-9 { width: 80%; padding-left: 30px; }")
        .and include("width: calc(19vw - 15px) !important;")
    end

    it "gives phones full-width content and a hamburger dropdown for the sidebar" do
      expect(html).to include("@media (max-width: 991px)")
        .and include(".navbar-toggle { display: block !important; }")
        .and include("body.gwp-nav-open #documentation-container > .row > .col-md-3 { display: block; }")
        .and include("max-height: calc(100vh - 51px); overflow-y: auto;")
        .and include(%q{button.removeAttribute("data-toggle")})
    end

    context "with custom sizes and font" do
      let(:options) { { page_width: 90, nav_width: 25, content_padding: 12, font: "Open Sans" } }

      it "uses them" do
        expect(html).to include("family=Open+Sans:")
          .and include("font-family: 'Open Sans'")
          .and include(".container { width: 90% !important;")
          .and include(".col-md-9 { width: 75%; padding-left: 12px; }")
          .and include("width: calc(22.5vw - 15px) !important;")
      end
    end
  end

  describe "idempotence" do
    it "changes nothing on a second run", :aggregate_failures do
      second = cleaner.clean(html)
      expect(second.html).to eq(html)
      expect(second.counts).to eq(admonitions: 0, mermaid: 0, headers: 0)
    end

    it "replaces its own styles and script when settings change", :aggregate_failures do
      again = described_class.new(page_width: 80, mermaid_version: 11).clean(html).html
      expect(again.scan("<!-- github-wiki-pub:head -->").size).to eq(1)
      expect(again.scan("gwp-nav-open\", open)").size).to eq(1)
      expect(again.scan("mermaid.initialize").size).to eq(1)
      expect(again).to include("width: 80% !important").and include("mermaid@11")
    end

    it "replaces the head block written by wiki-html-polish.rb" do
      legacy = WikiHtml::DOCUMENT.sub("</head>", "<!-- wiki-html-polish:head -->\n<style>\nold\n</style>\n</head>")
      expect(cleaner.clean(legacy).html).not_to include("wiki-html-polish")
    end

    it "replaces its own older head block, which ended at </style>" do
      older = WikiHtml::DOCUMENT.sub("</head>", "<!-- github-wiki-pub:head -->\n<style>\nold\n</style>\n</head>")
      expect(cleaner.clean(older).html).not_to include("<style>\nold\n")
    end
  end

  context "with every step turned off" do
    let(:options) { { admonitions: false, mermaid: false, dedupe_headers: false, styles: false } }

    it "returns the document unchanged" do
      expect(html).to eq(WikiHtml::DOCUMENT)
    end
  end

  describe "validation" do
    it "rejects unknown options" do
      expect { described_class.new(colour: true) }.to raise_error(ArgumentError, /unknown options: colour/)
    end

    it "rejects out-of-range widths" do
      expect { described_class.new(page_width: 120) }.to raise_error(ArgumentError, /page_width/)
    end

    it "rejects a blank font" do
      expect { described_class.new(font: " ") }.to raise_error(ArgumentError, /font/)
    end
  end
end
