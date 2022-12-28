require 'logger'
require_relative 'operation_helper'
require_relative 'operation/get_config'
require_relative 'operation/edit_config'
require_relative 'operation/get'
require_relative 'operation/commit'
require_relative 'operation/get_schema'

module NetconfEmulator::Operation

  def self.default_logger()
    logger = Logger.new(STDERR)
    logger.level = 'error'
    logger
  end

  class Processor
    def initialize(config, logger = NetconfEmulator::Operation.default_logger())
      @config = config
      @logger = logger
      @random = Random.new((Time.now.to_f * 1000000).to_i)
    end

    def process(request)
      op_config = @config.dig('operation', request.name.to_s)

      begin
        if op_config.nil?
          raise
        elsif op_config.has_key?('class')
          klass = Module.const_get('NetconfEmulator').const_get('Operation').const_get(op_config['class'])
          reply = klass.new(@config, @logger).call(request)
        elsif op_config.has_key?('rpc-reply')
          reply = Helper::document(op_config['rpc-reply'])
        else
          raise
        end

        if op_config.has_key?('sleep')
          msec = get_sleep_msec(op_config['sleep'])
          if msec > 0
            sleep(msec * 0.001)
          end
        end
      rescue Error => e
        reply = Helper::rpc_error(e.error)
      rescue => e
        #@logger.warn(e)
        reply = Helper::rpc_error({ 'error-type' => 'protocol', 'error-tag' => 'operation-not-supported', 'error-severity' => 'error' })
      end

      reply
    end

    private

    #
    # sleep: value
    # sleep: [ min, max ]
    #
    def get_sleep_msec(sleep_config)
      if sleep_config.is_a?(Integer)
        sleep_config
      elsif sleep_config.is_a?(Array) and sleep_config.size == 2 and sleep_config[0].is_a?(Integer) and sleep_config[1].is_a?(Integer)
        if sleep_config[0] < sleep_config[1]
          @random.rand(sleep_config[0]..sleep_config[1])
        else
          sleep_config[0]
        end
      else
        0
      end
    end
  end
end
