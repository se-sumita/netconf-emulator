require_relative 'xml'

module NetconfEmulator::Operation
  module Helper
    def self.build_document(element, value)
      if value.is_a?(String)
        element.text = value
      elsif value.is_a?(Object)
        value.each do |k, v|
          el = Xml::Element.create(k)
          build_document(el, v)
          element.add_element(el)
        end
      end
    end

    def self.document(obj)
      if obj.is_a?(String)
        k, v = obj, ''
      else
        k, v = obj.shift
      end
      root = Xml::Element.create(k)
      build_document(root, v)
      root
    end

    def self.ok()
      root = Xml::Element.create('ok')
      build_document(root, '')
      root
    end

    def self.rpc_error(error)
      root = Xml::Element.create('rpc-error')
      build_document(root, error)
      root
    end
  end
end
