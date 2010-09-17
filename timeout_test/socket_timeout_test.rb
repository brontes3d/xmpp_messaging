require File.dirname(__FILE__) + '/test_helper'
require 'base64'

class SimpleSSLClient

  def initialize(port)
    tcpsocket = TCPSocket.new("127.0.0.1", port)
    ctx = OpenSSL::SSL::SSLContext.new("TLSv1")
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    ctx.timeout = 4
    @sslsocket = OpenSSL::SSL::SSLSocket.new(tcpsocket, ctx)
  	@sslsocket.sync_close = true
    @sslsocket.connect
    
    @sslsocket.instance_eval do
      class << self
        def sysread(*args)
          time_called = Time.now
          to_return = super
          time_returned = Time.now
          
          time_diff = time_returned - time_called
          if time_diff > 1
            STDOUT.puts("Time diff: " + (time_diff).inspect)
          end

          # STDOUT.puts("sysread #{to_return.size}")
          to_return
        end
        def syswrite(str)
          # STDOUT.puts("syswrite #{str.size}")
          super
        end
      end
    end
    # 
    # @sslsocket = tcpsocket
  end
  
  def write(data)
    @sslsocket.write(data)
  end

  def read(arg)
    @sslsocket.read(arg)
  end
  
  def readline
    @sslsocket.readline
  end
  
end


class SocketTimeoutTest < Test::Unit::TestCase
  
  def test_socket_timeouts
      sslclient = SimpleSSLClient.new(12343)
      puts "client started"
    
      @lock = Mutex.new
    
      @reader = Thread.new do
        begin
          # while read_something = sslclient.read(1000000)
          while read_something = sslclient.readline
            STDOUT.puts "client reads: #{read_something.size}"
          end
        rescue => e
          puts e.inspect
          puts e.backtrace.join("\n")
        end
      end
    
      ever_increasing_write = Base64.encode64(File.read(__FILE__)).gsub("\n", " ")
      while true
        @lock.synchronize {
          puts "client about to write #{ever_increasing_write.size}"
          sslclient.write(ever_increasing_write)
          # sleep(2)
          # sslclient.write(ever_increasing_write)
          sslclient.write("\n")
          puts "client wrote #{ever_increasing_write.size}"          
        }
        ever_increasing_write += ever_increasing_write
        # ever_increasing_write
      end
          
    Thread.stop
  end
  
end