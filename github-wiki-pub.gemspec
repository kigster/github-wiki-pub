# frozen_string_literal: true

require_relative "lib/github/wiki/pub/version"

Gem::Specification.new do |spec|
  spec.name = "github-wiki-pub"
  spec.version = Github::Wiki::Pub::VERSION
  spec.authors = ["Konstantin Gredeskoul"]
  spec.email = ["kig@equilibris.ai"]

  spec.summary = "Publishes a GitHub wiki as a single, cleaned-up HTML document."
  spec.description = "Renders a markdown wiki to one HTML file with github-wikito-converter, then converts admonitions to callouts, mermaid code blocks to diagrams, removes duplicated headers, and sets the font and layout."
  spec.homepage = "https://github.com/kigster/github-wiki-pub"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kigster/github-wiki-pub"
  spec.metadata["changelog_uri"] = "https://github.com/kigster/github-wiki-pub/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "dry-cli", "~> 1.4"
  spec.add_dependency "dry-cli-autocomplete", "~> 0.5"
  spec.add_dependency "dry-cli-help", "~> 0.5"
  spec.add_dependency "dry-cli-ui", "~> 0.5"
  spec.add_dependency "tty-command", "~> 0.10"
  spec.add_dependency "zeitwerk", "~> 2.8"

  spec.post_install_message = <<~MESSAGE
    Thanks for installing github-wiki-pub! 

    The executable is 'gwp' so start with: gwp --help
  MESSAGE

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
