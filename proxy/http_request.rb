module Proxy
  class HTTPRequest
    include EM::Deferrable
    class BadRequest < StandardError; end

    attr_accessor :verb
    attr_accessor :uri
    attr_accessor :version
    attr_accessor :headers
    attr_accessor :body
    attr_accessor :username
    attr_accessor :client_ip
    attr_accessor :client_port

    attr_accessor :proxy_authenticate

    def initialize(data, options = {})
      self.client_ip = options[:client_ip]
      self.client_port = options[:client_port]
      self.body = ""
      self.username = "-"
      parse(data) if data
    end

    def has_authorization?
      headers && headers.has_key?('proxy-authorization')
    end

    def authorized?
      authorizer = Authorizer.new
      result = authorizer.auth(self)
      self.username = authorizer.username || "-"
      result
    end

    def post?
      self.verb == :post
    end

    def perform_request
      # TODO: Other possible headers (see RFC 2616, Section 5.3)
      before = MyFilter.new(self)
      before.callback {
        set_deferred_success(self)
      }
      before.errback { |message|
        # TODO: Perform logging (with 403) -> Or maybe HTTPResponse does all the logging and is called from main proxy loop
        set_deferred_failure(message)
      }
      before.perform
=begin
      options = { :uri => [self.uri.path, self.uri.query].join("?") }
      options[:cookie] = headers['cookie'] if headers.has_key?('cookie')
      options[:content] = self.body if post?
      conn = EM::Protocols::HttpClient2.connect(self.uri.host, self.uri.port)
      conn.send(self.verb, options)
=end
    end

    private
      # TODO: URI handler needs work - its a bit sensitive: http://analteenangels.com/css/smoothbox.css|analteenangels.css|main.css|warning.css
      def parse_request_line(line)
        verb, uri_str, version = line.split(/\s+/)
        # TODO: Handle CONNECT method
        # See http://muffin.doit.org/docs/rfc/tunneling_ssl.html
        # TODO: Handle VERB better (and limit the options, raise BadRequest if not valid)
        self.verb, self.uri, self.version = [ verb.downcase.to_sym, URI.parse(uri_str), version ]
      end

      def parse(data)
        begin
          StringIO.open(data) do |string|
            parse_request_line(string.readline)
            head = ""
            while (line = string.readline) != "\n" and !string.eof?
              head << line
            end
            self.body << line
            while !string.eof?
              self.body << string.readline
            end
            self.headers = WEBrick::HTTPUtils.parse_header(head)
          end
        rescue
          puts $!
          puts $!.backtrace
          raise BadRequest
        end
      end
  end
end

