# frozen_string_literal: true

require "dry/cli/ui"

module Github
  module Wiki
    module Pub
      # Every command the executable answers to.
      module CLI
        extend Dry::CLI::Registry

        Dry::CLI::Help.configure do
          title "github-wiki-pub"
          description "Builds and polishes the HTML published from a GitHub wiki."

          columns = IO.console&.winsize&.last || 80
          width [columns - 6, 120].min
          exit_code_without_arguments 0

          styles do
            heading :bold, :cyan, case: :UPPERCASE
            usage :yellow
            example :yellow
            option :green
            example_comment :bright_black
          end
        end

        register "clean-html", CleanHtml, aliases: ["-c", "--clean-html"]
        register "setup", Setup, aliases: ["-s"]
        register "wiki" do |wiki|
          wiki.register "to-html", Wiki::ToHtml, aliases: ["-t"]
        end
        register "version", Version, aliases: ["-V", "--version"]
        register "completion", Dry::CLI::Autocomplete::Command[self, program_name: "gwp"], aliases: ["-C"]
      end
    end
  end
end
