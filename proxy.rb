
require 'rubygems'
require 'eventmachine'
require 'base64'
require 'uri'
require 'webrick/httputils'
require 'active_support/core_ext'

require 'proxy/http_client'
require 'proxy/http_request'
require 'proxy/http_response'
require 'proxy/authorizer'
require 'proxy/filters'

require 'policy/client'

Proxy::Authorizer.use_auth = true

class ServerHandler < EventMachine::Connection
  #TODO: Include Proxy

  def finalize(http_response)
    send_data(http_response.respond)
    close_connection_after_writing
  end

  def receive_data(input)
    # Get the peer's details
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    puts input
    # TODO: Handle BadRequest
    # TODO: Why aren't we using evma_httpserver here?? Maybe the limited response options? Check it out anyway
    request = Proxy::HTTPRequest.new(input, :client_ip => ip, :client_port => port)
    # Policy Error
    request.errback { |options|
      result = case options[:reason]
        when 301 then Proxy::HTTPResponse.redirect(options[:to])
        when 403 then Proxy::HTTPResponse.access_denied(options[:message])
        when 407 then Proxy::HTTPResponse.auth_required(options[:realm])
      end
      finalize(result)
    }
    request.callback { |request|
      client = Proxy::HTTPClient.new(request)
      client.callback { |response|
        result = Proxy::HTTPResponse.new(response.status) do |http|
          http.headers = response.headers
          http.content = response.content
        end
        finalize(result)
      }
      # HTTP Error
      client.errback { |message|
        puts "Client ERROR: #{message}" # TODO: Log this?
        result = Proxy::HTTPResponse.new(200) do |http|
          # TODO: Handle specific errors like host not found or time out
          http.content = $!
          http.headers['content_type'] = "text/plain"
        end
        finalize(result)
      }
      client.perform_request
    }
    # Do it
    request.perform_request
  end
end

EM.run{
  _host = "0.0.0.0"
  _port = 8080
  EventMachine::start_server _host, _port, ServerHandler
  puts "Started EchoServer on #{_host}:#{_port}…"
}
