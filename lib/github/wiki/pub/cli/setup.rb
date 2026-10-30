# frozen_string_literal: true

require "dry/cli/ui"


module Github
  module Wiki
    module Pub
      module CLI
        class Setup < BaseCommand
          include Dry::CLI::UI

          desc "Install dependencies (requires node.js & npm"

          def call(**)
            if system("/usr/bin/env bash -c 'command -V gwtc >/dev/null 2>&1'")
              ui.info "github-wikito-converter is already installed, great!"
              return true
            end

            ui.puts "Installing github-wikito-converter NPM package..."
            exit 1 unless system("/usr/bin/env bash -c 'command -V npm >/dev/null 2>&1' || { echo 'npm not found, please install Node.js and npm.'; exit 1; }")
            result = system("npm install -g github-wikito-converter")
            if result
              ui.info "github-wikito-converter installed successfully."
            else
              ui.error "Failed to install github-wikito-converter."
              exit 1
            end
          end
        end
      end
    end
  end
end
