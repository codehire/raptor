require 'proxy/em_ext/httpclient2'

# See: http://github.com/maccman/nestful for a better HTTP client (see callbacks!)
# Incidentally, how will all this go with large downloads??
# Maybe check out em-http-request by igvita guy - this has a stream option which will be important for large files
# We send each chunk back to the client as we receive it to save memory in the proxy
module Proxy
  class HTTPClient
    include EM::Deferrable

    def initialize(request)
      @request = request
    end

    def perform_request
      options = { :uri => [@request.uri.path, @request.uri.query].join("?") }
      options[:cookie] = @request.headers['cookie'] if @request.headers.has_key?('cookie')
      options[:content] = @request.body if @request.post?
      client = EM::Protocols::HttpClient2.connect(@request.uri.host, @request.uri.port)
      client_response = client.send(@request.verb, options)
      client_response.callback { |response|
        set_deferred_success(response)
      }
    rescue
      # TODO: Check for different errors and codes
      set_deferred_failure($!)
    end
  end
end
