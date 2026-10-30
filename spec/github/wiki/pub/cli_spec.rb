# frozen_string_literal: true

RSpec.describe "github-wiki-pub", type: :aruba do
  def file(name) = File.read(expand_path(name))

  it "prints help and exits 0 without arguments" do
    run_command_and_stop("github-wiki-pub")
    expect(last_command_started).to have_output(/clean-html/)
  end

  it "prints the version" do
    run_command_and_stop("github-wiki-pub version")
    expect(last_command_started).to have_output(/\A#{Regexp.escape(Github::Wiki::Pub::VERSION)}$/)
  end

  it "prints a zsh completion script" do
    run_command_and_stop("github-wiki-pub completion zsh")
    expect(last_command_started).to have_output(/_gwp\(\)/)
  end

  describe "clean-html" do
    before do
      write_file("a.html", WikiHtml::DOCUMENT)
      write_file("b.html", WikiHtml::DOCUMENT)
    end

    it "cleans every file in place and reports the counts", :aggregate_failures do
      run_command_and_stop("github-wiki-pub clean-html a.html b.html")
      expect(last_command_started).to have_output(
        /a\.html: 2 admonitions, 2 mermaid diagrams, 1 duplicate headers removed\n.*b\.html: 2 admonitions/m
      )
      expect(file("b.html")).to include('<pre class="mermaid">')
    end

    it "passes layout flags through" do
      run_command_and_stop("github-wiki-pub clean-html a.html -w 90 -N 25 -p 10 -f Lato -m 11")
      expect(file("a.html")).to include("width: 90% !important").and include("family=Lato:").and include("mermaid@11")
    end

    it "skips the steps turned off" do
      run_command_and_stop("github-wiki-pub clean-html a.html --no-admonitions --no-mermaid --no-dedupe-headers --no-styles")
      expect(file("a.html")).to eq(WikiHtml::DOCUMENT)
    end

    it "writes nothing on a dry run", :aggregate_failures do
      run_command_and_stop("github-wiki-pub clean-html a.html --dry-run")
      expect(last_command_started).to have_output(/a\.html: would convert 2 admonitions.*\(dry run\)/)
      expect(file("a.html")).to eq(WikiHtml::DOCUMENT)
    end

    it "writes to --output and leaves the input alone", :aggregate_failures do
      run_command_and_stop("github-wiki-pub clean-html a.html -o out.html")
      expect(last_command_started).to have_output(/a\.html -> out\.html/)
      expect(file("a.html")).to eq(WikiHtml::DOCUMENT)
      expect(file("out.html")).to include("admonition-note")
    end

    it "backs up the original" do
      run_command_and_stop("github-wiki-pub clean-html a.html --backup")
      expect(file("a.html.bak")).to eq(WikiHtml::DOCUMENT)
    end

    it "never overwrites an existing backup", :aggregate_failures do
      write_file("a.html.bak", "older original")
      run_command_and_stop("github-wiki-pub clean-html a.html -b")
      expect(last_command_started).to have_output(/a\.html\.bak already exists, keeping it/)
      expect(file("a.html.bak")).to eq("older original")
    end

    it "does not back up an --output target that does not exist yet" do
      run_command_and_stop("github-wiki-pub clean-html a.html -o new.html -b")
      expect(exist?("new.html.bak")).to be(false)
    end

    it "refuses --output with several inputs" do
      run_command_and_stop("github-wiki-pub clean-html a.html b.html -o out.html", fail_on_error: false)
      expect(last_command_started).to have_exit_status(1).and have_output(/--output takes exactly one input file, got 2/)
    end

    it "fails on a missing file" do
      run_command_and_stop("github-wiki-pub clean-html missing.html", fail_on_error: false)
      expect(last_command_started).to have_exit_status(1).and have_output(/no such file: missing\.html/)
    end

    it "fails on a non-numeric width" do
      run_command_and_stop("github-wiki-pub clean-html a.html --page-width wide", fail_on_error: false)
      expect(last_command_started).to have_exit_status(1)
    end
  end
end
