require 'yaml'
require 'logger'
require 'optparse'
require_relative "netconf_emulator/version"
require_relative "netconf_emulator/message"

module NetconfEmulator
  class OptionParser
    attr_reader :options

    def initialize(argv)
      @options = {
        :config_dir => File.join(File.dirname($PROGRAM_NAME), '..', 'etc'),
        :version    => false
      }

      op = ::OptionParser.new
      op.on('-c', '--config-dir VALUE', String, "configuration directory") do |v|
        @options[:config_dir] = v
      end
      op.on('-v', '--version', "show version") do |v|
        @options[:version] = true
      end

      begin
        args = op.parse(argv)
      rescue ::OptionParser::InvalidOption => e
        STDERR.puts "ERROR: #{msg}"
        STDERR.puts ""
        STDERR.puts op
        exit 1
      end
    end
  end

  def self.run(argv)
    op = OptionParser.new(argv)
    if op.options[:version]
      STDERR.puts "version: #{VERSION}"
      return
    end

    config = {}

    Dir.glob("#{op.options[:config_dir]}/*.yml").sort.each do |file|
      config.merge!(YAML.load(File.read(file)))
    end
    Dir.chdir(op.options[:config_dir])

    logger_config = config['logger']
    if logger_config['file']
      logger = Logger.new(logger_config['file'])#, 10, 10*1024*1024)
    else
      logger = Logger.new(STDERR)
    end
    logger.level = logger_config['level'] || 'info'
    logger.datetime_format = logger_config['datetime_format'] || '%Y-%m-%dT%H:%M:%S.%06N'

    NetconfEmulator::Message.new(STDIN, STDOUT, config, logger).run
  end
end

if $PROGRAM_NAME == __FILE__
  NetconfEmulator::run(ARGV)
end
