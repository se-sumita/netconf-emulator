require 'rexml/document'

module REXML
  class Document
    def self.create(str)
      REXML::Document.new(str)
    end

    def pretty_xml
      self.context[:attribute_quote] = :quote
      formatter = REXML::Formatters::Pretty.new #(0)
      formatter.compact = true
      o = StringIO.new
      formatter.write(self, o)
      o.string
    end

    def simple_xml
      self.context[:attribute_quote] = :quote
      formatter = REXML::Formatters::Default.new
      o = StringIO.new
      formatter.write(self, o)
      o.string
    end

    def xpath(path, namespaces = nil)
      REXML::XPath.match(self, path, namespaces)
    end
  end

  class Element
    def self.create(str)
      REXML::Element.new(str)
    end

    def at_xpath(xpath, namespaces = nil)
      REXML::XPath::first(self, xpath, namespaces)
    end

    def get_attribute(name)
      self.attributes[name]
    end

    def at(name)
      self.elements[name]
    end

    def first
      self.elements[1]
    end

    def ancestors
      path = []
      node = self
      while node.parent
        break if node.name.empty?
        path << node
        node = node.parent
      end
      path.reverse
    end
  end
end

module Xml
  Document = REXML::Document
  Element  = REXML::Element
end
