
require 'proxy/status_codes'

def Header(name, value)
  "#{name}: #{value}\n"
end

module Proxy
  class HTTPResponse
    attr_accessor :headers, :content
    # Used only for 407 responses
    attr_accessor :auth_realm

    def initialize(code)
      @code = code
      self.headers = {}
      yield self if block_given?
    end

    def respond
      returning(response = "") do |response|
        response << status
        case @code
          when 407
            realm = self.auth_realm || 'Wally World'
            response << "Proxy-Authenticate: Basic realm=\"#{realm}\"\n\n"
          # TODO: Handle other non-OK responses
            # TODO: Implement 301 redirect
          else
            self.headers.each do |(key,value)|
              response << Header(key, value)
            end
            # TODO: One headers breaks shit but not sure which one!
            response << "\n"
            puts "RESPONSE: #{response}"
            response << self.content
        end
      end
    end

    def self.access_denied(message)
      self.new(403) do |http|
        # TODO: Later we can read the content from a file
        http.content = "403 Access Denied: #{message}"
        http.headers['content_type'] = "text/plain"
      end
    end

    def self.redirect(to)
      self.new(301) do |http|
        http.content = "#{to}"
      end
    end

    def self.auth_required(realm = nil)
      self.new(407) do |http|
        http.auth_realm = realm
      end
    end

    def status(options = {})
      version = options[:version] || "1.1"
      message = STATUS[@code]
      "HTTP/#{version} #{@code} #{message}\n"
    end
  end
end
