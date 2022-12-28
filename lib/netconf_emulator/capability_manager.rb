require_relative 'xml'

module NetconfEmulator::Operation
  class CapabilityManager
    def initialize(hello_file)
      @hello = Xml::Document.create(File.read(hello_file))
    end

    def candidate_enabled?
      result = @hello.at_xpath("/hello/capabilities/capability[contains(text(), 'urn:ietf:params:netconf:capability:candidate:')]")
      if result.nil?
        result = @hello.at_xpath("/*:hello/*:capabilities/*:capability[contains(text(), 'urn:ietf:params:netconf:capability:candidate:')]")
      end
      !result.nil?
    end

    def get_schema_enabled?
      true
    end
  end
end
