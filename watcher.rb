require 'json'
require 'faraday'
require 'faraday_middleware'

Process.daemon

class Watcher
  def initialize
    @conn = Faraday.new(url: 'http://ucchusma.herokuapp.com/api/v1') do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.request  :json
      faraday.response :json
    end

    ip_address = Socket.ip_address_list.find(&:ipv4_private?).ip_address
    resp = @conn.put do |req|
      req.url 'info'
      req.headers['Content-Type'] = 'application/json'
      req.body = { message: ip_address, token: ENV['TOKEN'] }.to_json
    end
  end

  def watch
    @count = 0
    @history ||= []

    loop do
      sleep 1
      
      begin
        @history << `cat /sys/class/gpio/gpio4/value`.to_i
        @count += 1
        next if @history.length < 10

        @count = 0 if @count >= 30
        @history.shift if @history.length > 30
        next unless @count % 10 == 0

        status = @history.count { |v| v == 1 } > 5 ? 'occupied' : 'vacant'

        resp = @conn.put do |req|
          req.url 'rooms/1'
          req.headers['Content-Type'] = 'application/json'
          req.body = { status: status, token: ENV['TOKEN'] }.to_json
        end
      rescue => e
        p e.message
      end
    end
  end
end

wacher = Watcher.new
wacher.watch

