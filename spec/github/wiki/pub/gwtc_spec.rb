# frozen_string_literal: true

require "tmpdir"

RSpec.describe Github::Wiki::Pub::Gwtc do
  subject(:gwtc) { described_class.new(executable: fake, runner:) }

  let(:fake) { File.expand_path("../../../fixtures/bin/gwtc", __dir__) }
  let(:runner) { TTY::Command.new(printer: :null) }
  let(:html_file) { File.join(tmp, "source.html").tap { |path| File.write(path, "<html></html>") } }
  let(:tmp) { Dir.mktmpdir }
  let(:wiki) { File.join(tmp, "wiki").tap { |dir| FileUtils.mkdir_p(dir) } }

  # Examples set PATH, GWTC and the fake's variables; none may leak into the next.
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
    FileUtils.rm_rf(tmp)
  end

  before { ENV["FAKE_GWTC_HTML"] = html_file }

  describe "#command" do
    it "maps the output file onto gwtc's directory and file name" do
      expect(gwtc.command("wiki", "/srv/docs/app.html")).to eq(
        [fake, File.expand_path("wiki"), "--format", "html", "--output", "/srv/docs", "--file-name", "app"]
      )
    end

    it "passes values, passes true booleans bare, and drops false and nil" do
      command = gwtc.command("wiki", "a.html", title: "Acme", toc_level: 2, disable_inline_assets: true,
                                               verbose: false, footer: nil)
      expect(command.last(5)).to eq(["--title", "Acme", "--toc-level", "2", "--disable-inline-assets"])
    end

    it "spells --toc-title the way gwtc does" do
      expect(gwtc.command("wiki", "a.html", toc_title: "Pages")).to include("--toctitle")
    end

    it "rejects options gwtc does not have" do
      expect { gwtc.command("wiki", "a.html", format: "pdf") }.to raise_error(ArgumentError, /unknown gwtc option: format/)
    end
  end

  describe "#to_html" do
    let(:output) { File.join(tmp, "nested", "dir", "app.html") }

    it "creates the output directory and returns the file written", :aggregate_failures do
      expect(gwtc.to_html(wiki, output, title: "Acme")).to eq(output)
      expect(File.read(output)).to eq("<html></html>")
      expect(File.read(output.sub(".html", ".args"))).to include("Acme")
    end

    it "fails when the wiki directory is missing" do
      expect { gwtc.to_html(File.join(tmp, "nope"), output) }.to raise_error(Github::Wiki::Pub::Error, /no such wiki directory/)
    end

    it "fails when the output is not .html" do
      expect { gwtc.to_html(wiki, "app.pdf") }.to raise_error(Github::Wiki::Pub::Error, /must end in \.html/)
    end

    it "fails with an install hint when gwtc is not installed" do
      missing = described_class.new(executable: "gwtc-not-installed-anywhere")
      expect { missing.to_html(wiki, output) }.to raise_error(Github::Wiki::Pub::Error, /npm install -g github-wikito-converter/)
    end

    it "fails when gwtc exits non-zero" do
      ENV["FAKE_GWTC_MODE"] = "fail"
      expect { gwtc.to_html(wiki, output) }.to raise_error(TTY::Command::ExitError, /something broke/)
    end

    it "fails when gwtc writes nothing" do
      ENV["FAKE_GWTC_MODE"] = "silent"
      expect { gwtc.to_html(wiki, output) }.to raise_error(Github::Wiki::Pub::Error, /wrote no/)
    end
  end

  describe "#available?" do
    it "finds an executable on PATH" do
      ENV["PATH"] = "#{File.dirname(fake)}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}"
      expect(described_class.new(executable: "gwtc")).to be_available
    end

    it "honours $GWTC" do
      ENV["GWTC"] = fake
      expect(described_class.new.executable).to eq(fake)
    end
  end

  # The real converter, when it is installed: proves the flags and the
  # output layout still match what gwtc does.
  describe "with the real gwtc", if: described_class.new(executable: "gwtc").available? do
    subject(:gwtc) { described_class.new(executable: "gwtc") }

    it "renders a wiki the cleaner understands" do
      File.write(File.join(wiki, "Home.md"), "# Home\n\n> [!NOTE]\n> Hello.\n\n```mermaid\nflowchart LR\n  A --> B\n```\n")
      output = gwtc.to_html(wiki, File.join(tmp, "out", "wiki.html"), title: "Test")
      counts = Github::Wiki::Pub::HtmlCleaner.new.clean(File.read(output)).counts
      expect(counts).to include(admonitions: 1, mermaid: 1)
    end
  end
end
