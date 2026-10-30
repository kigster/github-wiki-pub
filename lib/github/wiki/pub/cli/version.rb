# frozen_string_literal: true

module Github
  module Wiki
    module Pub
      module CLI
        class Version < Command
          desc "Print the version"

          def call(**)
            out.puts Github::Wiki::Pub::VERSION
          end
        end
      end
    end
  end
end
