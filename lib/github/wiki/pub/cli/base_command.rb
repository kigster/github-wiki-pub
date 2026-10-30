
module Github
  module Wiki
    module Pub
      module CLI
        class BaseCommand < Dry::CLI::Command
          include Dry::CLI::UI

          def call(**)
            super
          end
        end
      end
    end
  end
end
