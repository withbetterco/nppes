module Nppes
  module Workers
    class IniterWorker
      include Sidekiq::Worker

      def perform
        UpdatePack::Pack.init_base
      end
    end
  end
end
