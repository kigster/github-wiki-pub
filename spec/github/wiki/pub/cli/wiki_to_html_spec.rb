# frozen_string_literal: true

RSpec.describe "gwp wiki to-html", type: :aruba do
  def file(name) = File.read(expand_path(name))

  before do
    write_file("wiki/Home.md", "# Home\n")
    write_file("export.html", WikiHtml::DOCUMENT)
    set_environment_variable("GWTC", File.expand_path("../../../../fixtures/bin/gwtc", __dir__))
    set_environment_variable("FAKE_GWTC_HTML", expand_path("export.html"))
  end

  it "renders the wiki and cleans the result", :aggregate_failures do
    run_command_and_stop("gwp wiki to-html wiki -o site/app.html -t Acme")
    expect(last_command_started).to have_output(%r{wiki -> site/app\.html: 2 admonitions, 2 mermaid diagrams, 1 duplicate headers removed})
    expect(file("site/app.html")).to include("admonition-note").and include('<pre class="mermaid">')
  end

  it "passes gwtc's flags through" do
    run_command_and_stop("gwp wiki to-html wiki -o app.html -t Acme --toc wiki/Home.md --toc-title Pages " \
                         "--toc-level 2 --footer Fin --logo-img logo.png --css extra.css --highlight-theme monokai -d")
    expect(file("app.args").split("\n")).to include(
      "--title", "Acme", "--toc", "wiki/Home.md", "--toctitle", "Pages", "--toc-level", "2", "--footer", "Fin",
      "--logo-img", "logo.png", "--css", "extra.css", "--highlight-theme", "monokai", "--disable-inline-assets"
    )
  end

  it "passes the cleaner flags to the cleaner" do
    run_command_and_stop("gwp wiki to-html wiki -o app.html -w 90 -m 11")
    expect(file("app.html")).to include("width: 90% !important").and include("mermaid@11")
  end

  it "leaves gwtc's output alone with --no-clean", :aggregate_failures do
    run_command_and_stop("gwp wiki to-html wiki -o app.html --no-clean")
    expect(last_command_started).to have_output(/wiki -> app\.html$/)
    expect(file("app.html")).to eq(WikiHtml::DOCUMENT)
  end

  it "prints the gwtc command and writes nothing on a dry run", :aggregate_failures do
    run_command_and_stop("gwp wiki to-html wiki -o app.html -t 'Acme Wiki' -n")
    expect(last_command_started).to have_output(/gwtc .*--format html .*--file-name app --title Acme\\ Wiki/)
    expect(exist?("app.html")).to be(false)
  end

  it "writes documentation.html by default" do
    run_command_and_stop("gwp wiki to-html wiki")
    expect(exist?("documentation.html")).to be(true)
  end

  it "fails on a missing wiki directory" do
    run_command_and_stop("gwp wiki to-html nowhere -o app.html", fail_on_error: false)
    expect(last_command_started).to have_exit_status(1).and have_output(/no such wiki directory: nowhere/)
  end

  it "fails on a non-numeric --toc-level" do
    run_command_and_stop("gwp wiki to-html wiki --toc-level deep", fail_on_error: false)
    expect(last_command_started).to have_exit_status(1)
  end
end
