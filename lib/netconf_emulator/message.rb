#!/usr/bin/env ruby
# coding: utf-8
require 'logger'
require_relative 'xml'
require_relative 'operation_processor'

class NetconfEmulator::Message

  BUFFER_SIZE = 8192

  def initialize(input, output, config, logger)
    @input  = input
    @output = output
    @config = config
    @logger = logger
    @operation = NetconfEmulator::Operation::Processor.new(@config, @logger)
  end

  def run
    @logger.info("############################################################")
    @logger.info("# netconf start")
    @logger.info("############################################################")

    send_hello

    hello_received = false
    buffer = ''
    recv_chunk_length = 0
    recv_chunks = []

    loop do
      begin
        buffer = '' if buffer.nil?
        @logger.info("=== before read")
        chunk = @input.read_nonblock(BUFFER_SIZE)
        #next if chunk.nil?
        buffer += chunk
        @logger.info("=== read #{buffer.size}")
        @logger.info("[#{buffer}]")

        if !hello_received
          @logger.info("not hello_received")
          pos = buffer.index("]]>]]>")
          @logger.info("hello delim pos=#{pos}")
          unless pos.nil?
            buffer = buffer.byteslice(pos + 6, buffer.size - (pos + 6))
            unless buffer.nil?
              buffer = buffer.byteslice(1, buffer.size - 1) if buffer.start_with?("\r")
            end
            unless buffer.nil?
              buffer = buffer.byteslice(1, buffer.size - 1) if buffer.start_with?("\n")
            end
            hello_received = true
          end
        end

        if !buffer.nil? && hello_received
          @logger.info("already hello_received [#{recv_chunk_length}/#{buffer.bytesize}]")
          while recv_chunk_length < buffer.bytesize
            if recv_chunk_length == 0
              if buffer =~ /\A(\n)?#(\d+)\n/
                recv_chunk_length = $2.to_i
                buffer = $'
                @logger.debug("found start-of-chunks: #{recv_chunk_length}")
              elsif buffer.start_with?("\n##\n")
                @logger.debug("found end-of-chunks")
                msg = recv_chunks.join
                @logger.info("dispatching message[#{msg}]")
                dispatch_message(msg)
                recv_chunks = []
                buffer = buffer.byteslice(4, buffer.length - 4)
                buffer.sub!(/^\s*/, '')
                #@logger.info("  remaining buffer[#{buffer}]")
              end
            else
              #@logger.info("  recv_chunk_length[#{recv_chunk_length}] <= buffer.bytesize[#{buffer.bytesize}]")
              recv_chunks << '' if recv_chunks.empty?
              recv_chunks[-1] += buffer.byteslice(0, recv_chunk_length)
              #@logger.info("  recv_chunks[#{recv_chunks[-1]}]")
              buffer = buffer.byteslice(recv_chunk_length, buffer.length - recv_chunk_length)
              #@logger.info("  after buffer[#{buffer}]")
              recv_chunk_length = 0
            end
          end
        end
      rescue IO::WaitReadable
        @logger.info("=== IO::WaitReadable blocking")
        IO.select([@input])
        retry
      rescue EOFError
        @logger.info("=== EOF")
        break
      end
    end
    @logger.info("############################################################")
    @logger.info("# netconf finish")
    @logger.info("############################################################")
  rescue => e
    @logger.fatal("Exception")
    @logger.fatal(e)
  end

  DELIMITER = ']]>]]>'

  def format_msg(body)
    #"##{body.length}\n#{body}\n##\n\n"
    "\n##{body.length}\n#{body}\n##\n"
  end

  # helloを送信
  def send_hello
    xml = File.read(@config['hello'])
    msg = xml + DELIMITER
    #@output.puts msg
    @output.write(msg)
    @output.flush
    @logger.info("SEND HELLO\n#{msg}")
  end

  # helloを受信
  def recv_hello
    msg = ''
    while line = @input.gets
      line.chomp!
      @logger.info("line[#{line}]")
      msg += line + "\n"
      if line.end_with?(DELIMITER)
        msg += line.sub(/#{DELIMITER}$/, '') + "\n"
        break
      end
      #if line =~ /<\/hello>/
      #  break
      #end
    end
    @logger.info("RECV HELLO\n#{msg}")
  end

  def dispatch_message(recv_msg)
    doc_rpc = Xml::Document.create(recv_msg)
    doc_rpc_reply = Xml::Document.create('<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/>')

    rpc = doc_rpc.elements.first
    msg_id = rpc.attributes['message-id']
    doc_rpc_reply.elements['rpc-reply'].attributes['message-id'] = msg_id

    rpc.elements.each do |op|
      reply = @operation.process(op)
      doc_rpc_reply.elements['rpc-reply'].add(reply)
    end

    rpc_reply_msg = format_msg(doc_rpc_reply.simple_xml)
    @output.write rpc_reply_msg
    @output.flush
    @logger.info("SEND\n[#{rpc_reply_msg}]")

    if @config['dump-dir']
      File.write(File.join(@config['dump-dir'], "#{msg_id}_rpc.xml"), recv_msg)
      File.write(File.join(@config['dump-dir'], "#{msg_id}_rpc-reply.xml"), doc_rpc_reply.pretty_xml)
    end
  end
end
