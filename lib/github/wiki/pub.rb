# frozen_string_literal: true

require "dry/cli"
require "dry/cli/help"
require "dry/cli/ui"
require "dry/cli/autocomplete/command"
require "shellwords"
require "zeitwerk"

module Github
  module Wiki
    module Pub
      PROGRAM = "gwp"

      class Error < StandardError; end
    end
  end
end

loader = Zeitwerk::Loader.for_gem_extension(Github::Wiki)
loader.inflector.inflect("pub" => "Pub", "cli" => "CLI", "ui" => "UI")
loader.setup
