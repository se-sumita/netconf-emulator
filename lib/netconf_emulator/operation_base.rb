module NetconfEmulator::Operation
  class Error < StandardError
    attr_reader :error
    def initialize(error)
      @error = error
    end
  end

  class Base
    def initialize(config, logger)
      @config = config
      @logger = logger
    end

    def call(request)
      raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
    end
  end
end
