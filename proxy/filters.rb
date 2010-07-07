
module Proxy
  module Filter
    class AccessDenied < RuntimeError; end

    class Before
      def self.perform(request)
        MyFilter.new.perform(request)
      end

      def deny(options = {})
        raise AccessDenied, options[:message] || "Unknown Reason"
      end
    end
  end
end

class MyFilter < Proxy::Filter::Before
  # TODO: Try moving this include to the parent? Are filters always deferrable? 
  include EM::Deferrable

  def initialize(request)
    @request = request
  end

  def deny(message)
    set_deferred_failure(:reason => 403, :message => message)
  end
    
  def redirect(to)
    set_deferred_failure(:reason => 301, :to => to)
  end

  # TODO: Pass a scheme or authorizor symbol here when we support more than just basic!
  def authorized?(realm = 'Proxy Authentication')
    return true if @request.authorized?
    set_deferred_failure(:reason => 407, :realm => realm)
  end

  def allow
    set_deferred_success
  end

  def perform2
    authorize(:conditions => { :ip => "192.168.0.10" }) do

    end
  end

  def perform
    if authorized?
      puts "FILTERING ON #{@request.uri}, from #{@request.client_ip}"
      pr = Policy::Request.new(:access) do |r|
        r.username = @request.username
      end
      client = Policy::Client.check(pr)
      client.callback { allow }
      client.errback { |policy|
        deny(policy.message)
      }
    end
  end
end
