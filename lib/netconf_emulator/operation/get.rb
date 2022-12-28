require_relative '../operation_base'
require_relative '../operation_helper'
require_relative '../datastore_manager'
require_relative 'get_config'

module NetconfEmulator::Operation
  class Get < GetConfig
    def call(request)
      prefix = request.prefixes.empty? ? '' : "#{request.prefixes[-1]}:"
      filter = request.at("#{prefix}filter")
      dsm = DatastoreManager.new(@config)
      ds = dsm.load('running-state')
      if ds.nil?
        Helper::rpc_error({ 'error-type' => 'protocol', 'error-tag' => 'unknown-element', 'error-severity' => 'error' })
      else
        retrieve(ds, filter)
      end
    end
  end
end
