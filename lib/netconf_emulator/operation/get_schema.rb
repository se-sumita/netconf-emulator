require_relative '../operation_base'
require_relative '../operation_helper'

module NetconfEmulator::Operation
  class GetSchema < Base
    def call(request)
      prefix = request.prefixes.empty? ? '' : "#{request.prefixes[-1]}:"

      identifier = request.at("#{prefix}identifier")
      if identifier.nil?
        return Helper::rpc_error({ 'error-type' => 'protocol', 'error-tag' => 'invalid-value', 'error-severity' => 'error' })
      end
      identifier = identifier.text

      ver = request.at("#{prefix}version")
      version = ver.nil? ? '*' : ver.text

      fmt = request.at("#{prefix}format")
      format = fmt.nil? ? 'yang' : fmt.text

      filename = "#{identifier}@#{version}.#{format}"
      filepath = File.join(@config['schema-dir'], filename)
      @logger.debug("filepath[#{filepath}]")

      files = Dir.glob(filepath)
      @logger.debug(files)
      if files.empty?
        # If the requested schema does not exist, the <error-tag> is
        # 'invalid-value'.
        Helper::rpc_error({ 'error-type' => 'protocol', 'error-tag' => 'invalid-value', 'error-severity' => 'error' })
      elsif files.size > 1
        # If more than one schema matches the requested parameters, the
        # <error-tag> is 'operation-failed', and <error-app-tag> is
        # 'data-not-unique'.
        Helper::rpc_error({ 'error-type' => 'protocol', 'error-tag' => 'operation-failed', 'error-app-tag' => 'data-not-unique', 'error-severity' => 'error' })
      else
        schema = File.read(files[0])
        data = Xml::Element.create('data')
        data.attributes['xmlns'] = 'urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring'
        data.text = schema
        data
      end
    end
  end
end
