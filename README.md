# github-wiki-pub

![Coverage](docs/badges/coverage_badge.svg)

Publishes a GitHub wiki as a single HTML document that reads well.

A wiki exported from markdown to HTML loses what GitHub renders for you: `> [!NOTE]` admonitions arrive as plain quotes with a literal `[!NOTE]`, mermaid diagrams arrive as highlighted source code, and each page carries its title twice. `github-wiki-pub` fixes the export in place. It is for whoever publishes the wiki, a person or an agent, and it is safe to run any number of times on the same file.

It will grow to replace the `bin/wiki-gen` and `bin/wiki-publish` scripts of `equilibris-atlas`, kept for reference at the root of this repository as `wiki-gen`, `wiki_gen/pages.rb` and `wiki-publish`. They are not part of the gem.

## Installation

Requires Ruby 4.0 or later.

```bash
gem install github-wiki-pub
```

`wiki to-html` also needs Node and the converter, see below.

## Commands

The executable is installed twice, as `github-wiki-pub` and as the shorter `gwp`.

```text
gwp wiki to-html WIKI_DIR [-o FILE.html] [OPTIONS]   # render a markdown wiki to one HTML file, then clean it
gwp clean-html FILES... [OPTIONS]                  # clean wiki HTML exports
gwp version                                        # print the version (also -V, --version)
gwp completion bash|zsh                            # print a shell completion script
```

### `wiki to-html`

```bash
gwp wiki to-html ./wiki -o docs/wiki-app.html -t "Example App"
```

Renders the wiki with [github-wikito-converter](https://github.com/yakivmospan/github-wikito-converter) (`gwtc`), then runs every `clean-html` step on the result. It needs Node and the converter:

```bash
npm install -g github-wikito-converter
```

Set `GWTC` to run a different `gwtc` executable. The converter's own flags pass straight through:

| Option                           | Default              | gwtc flag                 |
| :------------------------------- | :------------------- | :------------------------ |
| `-t`, `--title`                  | `Documentation`      | `--title`                 |
| `--toc`                          | gwtc's `_Sidebar.md` | `--toc`                   |
| `--toc-title`                    | `Table of contents`  | `--toctitle`              |
| `--toc-level`                    | `3`                  | `--toc-level`             |
| `--footer`                       |                      | `--footer`                |
| `--logo-img`                     |                      | `--logo-img`              |
| `--css`                          |                      | `--css`                   |
| `--highlight-theme`              | `github`             | `--highlight-theme`       |
| `-d`, `--disable-inline-assets`  | off                  | `--disable-inline-assets` |
| `-v`, `--verbose`                | off                  | `--verbose`, and shows gwtc's own output |

`-o FILE.html` (default `documentation.html`) becomes gwtc's `--output` directory and `--file-name`, and the directory is created first: gwtc writes nothing, and still exits 0, when it is missing. `--no-clean` keeps gwtc's output as it is, `-n` prints the gwtc command without running it, and every `clean-html` layout and step flag below applies here too. PDF output is not offered.

### `clean-html`

```bash
github-wiki-pub clean-html wiki-app.html wiki-atlas.html
```

It does four things, each of which can be turned off:

| Step                                                                                      | Off switch            |
| :---------------------------------------------------------------------------------------- | :-------------------- |
| `> [!NOTE]`, `TIP`, `IMPORTANT`, `WARNING`, `CAUTION` become colored callouts with Font Awesome icons | `--no-admonitions`    |
| Mermaid code blocks become `<pre class="mermaid">`, and the mermaid script is loaded once | `--no-mermaid`        |
| The duplicated `<h1>` without an `id` is removed from each page                           | `--no-dedupe-headers` |
| The base font, page width, navigation width and content padding are set                  | `--no-styles`         |

| Option                      | Default  | Meaning                                                |
| :-------------------------- | :------- | :----------------------------------------------------- |
| `-w`, `--page-width`        | `95`     | Page width, in % of the browser                        |
| `-N`, `--nav-width`         | `20`     | Navigation bar width, in % of the page                 |
| `-p`, `--content-padding`   | `30`     | Left padding of the content pane, in px                |
| `-f`, `--font`              | `Nunito` | Base font, loaded from Google Fonts                    |
| `-m`, `--mermaid-version`   | `9`      | Major version of mermaid to load                       |
| `-o`, `--output`            |          | Write here instead of in place (one input file only)   |
| `-b`, `--backup`            | off      | Copy each file to `FILE.bak` first; never overwrites an existing backup |
| `-n`, `--dry-run`           | off      | Report what would change, write nothing                |

Mermaid 9 cannot read a diagram's `---` front-matter, so with `-m 9` the front-matter's `config` is rewritten as the equivalent `%%{init: ...}%%` directive. With `-m 10` or later it is left as written. Options such as `layout: elk` and `look: handDrawn` need mermaid 11.

## Development

```bash
direnv allow .          # puts bin/ and exe/ on PATH
bundle install
bundle exec rake        # specs, with a 95% coverage floor
bundle exec rubocop
bundle exec rspec spec/github/wiki/pub/html_cleaner_spec.rb   # one spec file
bundle exec rake doc    # YARD documentation
bundle exec rake gem    # build and install the gem locally
```

Every spec run rewrites `docs/badges/coverage_badge.svg`.

The CLI specs run through Aruba in-process, so the CLI counts towards coverage. They never call the real converter: `spec/fixtures/bin/gwtc` stands in for it through `GWTC`.

The cleaning itself lives in `Github::Wiki::Pub::HtmlCleaner`; the `clean-html` command only parses flags and handles files.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
