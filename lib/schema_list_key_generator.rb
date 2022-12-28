#!/usr/bin/env ruby
require 'json'

module SchemaListKeyGenerator
  def self.parse(schema_list_key, ancestors, obj)
    type = obj[0]
    if type == 'list'
      path = "/#{ancestors.map{|p| p.split(':')[-1]}.join('/')}"
      schema_list_key[path] = obj[2].map{|x| x[1]}
    end
    if type == 'list' or type == 'container'
      obj[1].each do |k, v|
        parse(schema_list_key, ancestors + [k], v)
      end
    end
  end

  def self.parse_jtox(jtox)
    schema_list_key = {}
    jtox['tree'].each do |k, v|
      parse(schema_list_key, [k], v)
    end
    puts "schema-list-key:"
    schema_list_key.each do |path, keys|
      if keys.size > 0
          puts "  #{path}: [#{keys.join(', ')}]"
      end
    end
  end

  def self.create_jtox(yang_dir)
    cmd = "pyang --ignore-errors -f jtox -p #{yang_dir} #{yang_dir}/*.yang"
    stdout = ''
    IO.popen(cmd, "r+") do |io|
      io.close_write
      stdout = io.gets
    end
    JSON.parse(stdout)
  end

  def self.run(argv)
    yang_dir = argv.shift
    if yang_dir.nil?
      STDERR.puts "usage: #{$PROGRAM_NAME} yang-directory"
      STDERR.puts ""
      return
    end

    jtox = create_jtox(yang_dir)
    parse_jtox(jtox)
  end
end

if $PROGRAM_NAME == __FILE__
  SchemaListKeyGenerator::run(ARGV)
end
