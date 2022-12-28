require 'fileutils'
require_relative 'xml'

module NetconfEmulator::Operation
  class DatastoreManager

    #TOP_PATH = '/x:rpc-reply/x:data'
    TOP_PATH = '/rpc-reply/data'

    def initialize(config)
      @config = config
    end

    def load(source)
      xml_file = ds_file_path(source)
      if File.file?(xml_file)
        Xml::Document.create(File.read(xml_file))
      else
        nil
      end
    end

    def str(source)
      doc = load(source)
      doc.pretty_xml
    end

    def exist?(target)
      target_file = ds_file_path(target)
      File.file?(target_file)
    end

    def move(source, target)
      source_file = ds_file_path(source)
      target_file = ds_file_path(target)
      if File.file?(source_file)
        FileUtils.move(source_file, target_file, { force: true })
      end
    end

    def remove(target)
      target_file = ds_file_path(target)
      if File.file?(target_file)
        FileUtils.remove_file(target_file, { force: true })
      end
    end

    def save(target, ds)
      target_file = ds_file_path(target)
      File.write(target_file, ds.pretty_xml)
    end

    def lock(target)
    end

    def unlock(target)
    end

    private

    def ds_file_path(name)
      File.join(@config['datastore-dir'], "#{name}.xml")
    end
  end
end
