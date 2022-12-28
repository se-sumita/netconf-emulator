require_relative '../operation_base'
require_relative '../operation_helper'
require_relative '../datastore_manager'

module NetconfEmulator::Operation
  class EditConfig < Base
    def call(request)
      prefix = request.prefixes.empty? ? '' : "#{request.prefixes[-1]}:"
      target = request.at("#{prefix}target").first.name
      default_operation = request.at("#{prefix}default-operation")
      if default_operation.nil?
        default_operation = 'merge'
      else
        default_operation = default_operation.get_text.value || 'merge'
      end

      dsm = DatastoreManager.new(@config)

      ds_hash = {}

      [ '', '-state' ].each do |ext|
        label = "#{target}#{ext}"
        case target
        when 'running'
          read_label = label
        when 'candidate'
          capability = CapabilityManager.new(@config['hello'])
          if capability.candidate_enabled?
            if dsm.exist?(label)
              read_label = label
            else
              read_label = "running#{ext}"
            end
          else
            # TODO
            raise Error.new(
              {
                'error-type'     => 'protocol',
                'error-tag'      => 'operation-not-supported',
                'error-severity' => 'error'
              }
            )
          end
        else
          raise Error.new(
            {
              'error-type'     => 'protocol',
              'error-tag'      => 'unknown-element',
              'error-severity' => 'error',
              'error-path'     => '/rpc/get-config/target',
              'error-info'     => {
                'bad-element'  => target
              }
            }
          )
        end

        ds = dsm.load(read_label)

        if ds.nil?
          @logger.warn("not found source [#{label}] (#{read_label})")
          raise Error.new({ 'error-type' => 'protocol', 'error-tag' => 'unknown-element', 'error-severity' => 'error' })
        end

        target_node = ds.elements['rpc-reply/data']
        config_node = request.elements['config']
        config_node = request.elements['nc:config'] if config_node.nil?
        config_node.elements.each do |cn|
          operate_node(target_node, cn, default_operation, default_operation)
        end

        ds_hash[label] = ds
      end

      ds_hash.each do |label, ds|
        dsm.save(label, ds)
      end

      Helper::ok()
    rescue Error => e
      Helper::rpc_error(e.error)
    rescue => e
      @logger.fatal(e)
      raise
    end

    private

    def operate_node(target_parent, config_node, default_op_type, op_type)
      case op_type.to_s.to_sym
      when :merge
        merge_node(target_parent, config_node, default_op_type)
      when :replace
        replace_node(target_parent, config_node, default_op_type)
      when :create
        create_node(target_parent, config_node, default_op_type)
      when :delete
        delete_node(target_parent, config_node, default_op_type)
      when :remove
        remove_node(target_parent, config_node, default_op_type)
      when :none
        none_node(target_parent, config_node, default_op_type)
      else
      end
    end

    def find_child_element(target_parent, config_node)
      ancestors = config_node.ancestors
      ancestors.shift if ancestors[0].name == 'rpc'
      ancestors = ancestors[2..-1].map{ |n| n.name }
      path = '/' + ancestors.join('/')
      keys = @config['schema-list-key'][path]
      if keys.nil?
        target_parent.elements[config_node.name]
      else
        condition = keys.map{ |key| "#{key}='#{config_node.elements[key].get_text.value.strip}'" }.join(' and ')
        target_parent.at_xpath("#{config_node.name}[#{condition}]")
      end
    end

    def deep_clone(target_parent, config_node, default_op_type, op_type)
      target_node = config_node.clone
      target_node.delete_attribute('operation')
      target_node.text = config_node.text
      target_parent.add(target_node)
      config_node.elements.each do |cn|
        operate_node(target_node, cn, default_op_type, op_type)
      end
    end

    def merge_node(target_parent, config_node, default_op_type)
      # The configuration data identified by the element
      # containing this attribute is merged with the configuration
      # at the corresponding level in the configuration datastore
      # identified by the <target> parameter.  This is the default
      # behavior.
      target_node = find_child_element(target_parent, config_node)
      if target_node.nil?
        deep_clone(target_parent, config_node, default_op_type, :merge)
      else
        target_node.text = config_node.text
        config_node.elements.each do |cn|
          cn_op_type = cn.attributes.get_attribute('operation')
          if cn_op_type.nil?
            cn_op_type = default_op_type
          else
            cn_op_type = cn_op_type.to_s
          end
          operate_node(target_node, cn, default_op_type, cn_op_type)
        end
      end
    end

    def replace_node(target_parent, config_node, default_op_type)
      target_node = find_child_element(target_parent, config_node)
      if target_node.nil?
        # If no such configuration data exists in the
        # configuration datastore, it is created.
        deep_clone(target_parent, config_node, default_op_type, :replace)
      else
        # The configuration data identified by the element
        # containing this attribute replaces any related configuration
        # in the configuration datastore identified by the <target>
        # parameter.
        target_node.text = config_node.text
        target_node.elements.each do |tn|
          target_node.delete_element(tn)
        end
        config_node.elements.each do |cn|
          deep_clone(target_node, cn, default_op_type, :replace)
        end

        # @note
        # To avoid changing the order of list elements,
        # delete all children and append all children
        # without deleting and appending the self element.

        #target_parent.delete_element(target_node)
        #deep_clone(target_parent, config_node, default_op_type, :replace)
      end
    end

    def create_node(target_parent, config_node, default_op_type)
      target_node = find_child_element(target_parent, config_node)
      if target_node.nil?
        # The configuration data identified by the element
        # containing this attribute is added to the configuration if
        # and only if the configuration data does not already exist in
        # the configuration datastore.
        deep_clone(target_parent, config_node, default_op_type, :create)
      else
        # If the configuration data exists,
        # an <rpc-error> element is returned with an <error-tag> value of "data-exists".
        raise Error.new({ 'error-type' => 'protocol', 'error-tag' => 'data-exists', 'error-severity' => 'error' })
      end
    end

    def delete_node(target_parent, config_node, default_op_type)
      target_node = find_child_element(target_parent, config_node)
      if target_node.nil?
        # If the configuration data does not exist,
        # an <rpc-error> element is returned with an <error-tag> value of "data-missing".
        raise Error.new({ 'error-type' => 'protocol', 'error-tag' => 'data-missing', 'error-severity' => 'error' })
      else
        # The configuration data identified by the element
        # containing this attribute is deleted from the configuration
        # if and only if the configuration data currently exists in
        # the configuration datastore.
        target_parent.delete_element(target_node)
      end
    end

    def remove_node(target_parent, config_node, default_op_type)
      target_node = find_child_element(target_parent, config_node)
      if target_node.nil?
        # If the configuration data does not exist,
        # the "remove" operation is silently ignored by the server.
      else
        # The configuration data identified by the element
        # containing this attribute is deleted from the configuration
        # if the configuration data currently exists in the
        # configuration datastore.
        target_parent.delete_element(target_node)
      end
    end

    # none:  The target datastore is unaffected by the configuration
    #    in the <config> parameter, unless and until the incoming
    #    configuration data uses the "operation" attribute to request
    #    a different operation.  If the configuration in the <config>
    #    parameter contains data for which there is not a
    #    corresponding level in the target datastore, an <rpc-error>
    #    is returned with an <error-tag> value of data-missing.
    #    Using "none" allows operations like "delete" to avoid
    #    unintentionally creating the parent hierarchy of the element
    #    to be deleted.
    def none_node(target_parent, config_node, default_op_type)
      target_node = find_child_element(target_parent, config_node)
      if target_node.nil?
        raise Error.new({ 'error-type' => 'protocol', 'error-tag' => 'data-missing', 'error-severity' => 'error' })
      else
        target_node.text = config_node.text
        config_node.elements.each do |cn|
          cn_op_type = cn.attributes.get_attribute('operation')
          if cn_op_type.nil?
            cn_op_type = default_op_type
          else
            cn_op_type = cn_op_type.to_s
          end
          operate_node(target_node, cn, cn_op_type, cn_op_type)
        end
      end
    end
  end
end
