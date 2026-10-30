# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Ruby gem `github-wiki-pub` (executables `github-wiki-pub` and `gwp`). It turns a GitHub markdown wiki into one readable HTML document: renders via the `gwtc` npm package (github-wikito-converter), then fixes what the export loses (admonitions, mermaid, duplicate `<h1>`s, layout styles). README.md is the user-facing reference for every flag.

## Commands

```bash
direnv allow .                                  # puts bin/ and exe/ on PATH, sets RUBYOPT=-W0
bundle install
bundle exec rake                                # full spec suite; fails under 95% line coverage
bundle exec rspec spec/github/wiki/pub/html_cleaner_spec.rb      # one file
bundle exec rspec spec/github/wiki/pub/html_cleaner_spec.rb:42   # one example
bundle exec rubocop                             # lint (relaxed.ruby.style + rubocop-rspec/rake)
bundle exec rake doc                            # YARD docs
bundle exec rake gem                            # build and install locally
```

There is no justfile. The coverage run rewrites `docs/badges/coverage_badge.svg`, so a spec run leaves that file modified.

## Architecture

- `lib/github/wiki/pub.rb` boots Zeitwerk with inflections `pub => Pub`, `cli => CLI`. File paths must match constant names under that rule; there are no `require`s for gem-internal files.
- `exe/gwp` deliberately skips Bundler and calls `Launcher.new(ARGV).execute!`. `Launcher` wraps `Dry::CLI`, turns `SystemExit` into a status, prints `error: ...` on exceptions (backtrace with `-v`), and exits only through the injected `kernel`.
- `CLI` (`cli.rb`) is the dry-cli registry. Commands inherit `CLI::Command`, which adds `-v/--verbose` to every subclass via `inherited`. Nested commands (`wiki to-html`) live under `cli/wiki/`.
- `CLI::CleanerOptions` holds the layout/step flags shared by `clean-html` and `wiki to-html`.
- Logic lives outside the CLI layer, which only parses flags and handles files:
  - `HtmlCleaner` does all HTML rewriting with regex over the raw string (no HTML parser) and returns `Result(html, counts)`. Every step must stay idempotent: running it twice on a file is a supported use.
  - `Gwtc` shells out to the converter via `tty-command`. `FLAGS` maps option names to gwtc flags. `ENV["GWTC"]` overrides the executable.
- Mermaid 9 cannot read `---` front-matter, so with `mermaid_version: 9` the cleaner rewrites front-matter `config` into a `%%{init: ...}%%` directive. With 10 or later it leaves it alone.

## Testing

- CLI specs use Aruba **in-process** (`spec/support/aruba.rb`): Aruba builds a `Launcher` per example, so CLI code counts toward coverage. Keep `Launcher`'s injectable argv/streams/kernel signature.
- `spec/fixtures/bin/gwtc` is a fake converter selected via `GWTC`. It writes `$FAKE_GWTC_HTML` as output; `FAKE_GWTC_MODE=fail` exits 1, `FAKE_GWTC_MODE=silent` exits 0 without writing (mimics real gwtc when the output dir is missing).
- `spec/support/wiki_html.rb` (`WikiHtml::DOCUMENT`) is a miniature export with one of everything the cleaner rewrites. Extend it when adding a cleaning step.
- RSpec runs in random order with monkey patching disabled; `rspec-its` is available.

## Legacy scripts at the repo root

`wiki-gen`, `wiki_gen/pages.rb` and `wiki-publish` were copied from the `equilibris-atlas` repo, where they live as `bin/wiki-gen` and `bin/wiki-publish`. Their paths and `ROOT`/`REPO` constants still point there. The gem is meant to replace them gradually. Treat them as reference for future commands, not as part of the gem: they are not loaded, linted for the gem, or covered by specs.

## Gotchas

- The gemspec requires Ruby >= 4.0 (`.ruby-version` is 4.0.6), but CI (`.github/workflows/main.yml`) still pins Ruby 3.2.3, so CI cannot install the gem until that is bumped. CI triggers on pushes to `master`.
- `rake build` runs `permissions` first, which `chmod`s the whole tree world-readable except `.env*`.
