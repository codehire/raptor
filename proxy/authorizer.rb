$users = {
  'daniel' => '12qwaszx',
  'jordyn' => 'test'
}

module Proxy
  class Authorizer
    cattr_accessor :use_auth
    attr_accessor :username

    def auth(request)
      return true unless self.class.use_auth
      return false unless request.has_authorization?
      if auth = request.headers['proxy-authorization']
        pair = auth[0].split(/\s+/)
        puts "pair = #{pair.inspect}"
        case pair[0]
          when 'Basic'
            puts pair.inspect
            self.username, pass = Base64.decode64(pair[1]).split(":")
            return ($users[self.username] && $users[self.username] == pass)
        end
      end
    end
  end
end
