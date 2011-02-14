require 'rubygems'
require 'socket'
require 'sdp'

module RTSP

  # Parses raw response data from the server/client and turns it into
  # attr_readers.
  class Response
    attr_reader :code
    attr_reader :message
    attr_reader :body

    # @param [String] raw_response The raw response string returned from the
    # server/client.
    def initialize(raw_response)
      response_array = raw_response.split "\r\n\r\n"

      if response_array.empty?
        response_array = raw_response.split "\n\n"
      end

      head = response_array.first
      body = response_array.last == head ? "" : response_array.last
      parse_head(head)
      @body = parse_body(body)

      unless @code == 200
        raise "#{@code}: #{@message}"
      end
    end

    # Reads through each line of the RTSP response and creates a
    # snake-case accessor with that value set.
    #
    # @param [String] head
    def parse_head head
      lines = head.split "\r\n"

      lines.each_with_index do |line, i|
        if i == 0
          line =~ /RTSP\/1.0 (\d\d\d) ([^\r\n]+)/
          @code = $1.to_i
          @message = $2
          next
        end
        
        if line.include? ": "
          header_field = line.strip.split(": ")
          header_name = header_field.first.downcase.gsub(/-/, "_")
          create_reader(header_name, header_field.last)
        end
      end
    end

    # Reads through each line of the RTSP response body and parses it if
    # needed.
    #
    # @param [String] body
    def parse_body body
      #response[:body] = read_nonblock(size).split("\r\n") unless @content_length == 0
      if body =~ /^(\r\n|\n)/
        body.gsub!(/^(\r\n|\n)/, '')
      end

      if @content_type == "application/sdp"
        SDP.parse body
      end
    end

    # @param [Number] size
    # @param [Hash] options
    # @option options [Number] time Duration to read on the non-blocking socket.
    def read_nonblock(size, options={})
      options[:time] ||= 1
      buffer = nil
      timeout(options[:time]) { buffer = @socket.read_nonblock(size) }

      buffer
    end

    private

    # Creates an attr_reader with the name given and sets it to the value that's
    # given.
    #
    # @param [String] name
    # @param [String] value
    def create_reader(name, value)
      value = value =~ /^[0-9]*$/ ? value.to_i : value

      instance_variable_set("@#{name}", value)
      self.instance_eval "def #{name}; @#{name}; end"
    end
  end
end
