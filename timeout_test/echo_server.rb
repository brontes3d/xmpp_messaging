require 'socket'
require 'openssl'

class SimpleSSLServer
  
  # def setup_certificate
  #   if @cert && @pkey
  #     return
  #   end
  # 
  #   rsa = OpenSSL::PKey::RSA.new(512){|p, n|
  #     case p
  #     when 0; $stderr.putc "."  # BN_generate_prime
  #     when 1; $stderr.putc "+"  # BN_generate_prime
  #     when 2; $stderr.putc "*"  # searching good prime,
  #       # n = #of try,
  #       # but also data from BN_generate_prime
  #     when 3; $stderr.putc "\n" # found good prime, n==0 - p, n==1 - q,
  #       # but also data from BN_generate_prime
  #     else;   $stderr.putc "*"  # BN_generate_prime
  #     end
  #   }
  # 
  #   cert = OpenSSL::X509::Certificate.new
  #   cert.version = 3
  #   cert.serial = 0
  #   name = OpenSSL::X509::Name.new([["CN","fqdn.example.com"]])
  #   cert.subject = name
  #   cert.issuer = name
  #   cert.not_before = Time.now
  #   cert.not_after = Time.now + (365*24*60*60)
  #   cert.public_key = rsa.public_key
  # 
  #   ef = OpenSSL::X509::ExtensionFactory.new(nil,cert)
  #   cert.extensions = [ef.create_extension("basicConstraints","CA:FALSE"),ef.create_extension("subjectKeyIdentifier", "hash") ]
  #   ef.issuer_certificate = cert
  #   cert.add_extension(ef.create_extension("authorityKeyIdentifier",
  #   "keyid:always,issuer:always"))
  #   cert.add_extension(ef.create_extension("nsComment", "Generated by Ruby/OpenSSL"))
  #   cert.sign(rsa, OpenSSL::Digest::SHA1.new)
  # 
  #   @cert = cert
  #   @pkey = rsa
  # end

  def setup_ssl_context
    ctx = ::OpenSSL::SSL::SSLContext.new('TLSv1')
    
    key = OpenSSL::PKey::RSA.new(1024){ print "."; $stdout.flush }
    puts
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 0
    name = OpenSSL::X509::Name.new([["C","JP"],["O","TEST"],["CN","localhost"]])
    cert.subject = name
    cert.issuer = name
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600
    cert.public_key = key.public_key
    ef = OpenSSL::X509::ExtensionFactory.new(nil,cert)
    cert.extensions = [
      ef.create_extension("basicConstraints","CA:FALSE"),
      ef.create_extension("subjectKeyIdentifier","hash"),
      ef.create_extension("extendedKeyUsage","serverAuth"),
      ef.create_extension("keyUsage",
                          "keyEncipherment,dataEncipherment,digitalSignature")
    ]
    ef.issuer_certificate = cert
    cert.add_extension ef.create_extension("authorityKeyIdentifier",
                                           "keyid:always,issuer:always")
    cert.sign(key, OpenSSL::Digest::SHA1.new)
    
    ctx.cert = cert
    ctx.key = key
    
    # ctx.cert            = OpenSSL::PKey::RSA.new(File.read(File.dirname(__FILE__) + '/cert.pem'))
    # @cert
    # ctx.key             = OpenSSL::X509::Certificate.new(File.read(File.dirname(__FILE__) + '/key.pem'))
    # @pkey
    # ctx.client_ca       = nil
    # ctx.ca_path         = nil
    # ctx.ca_file         = nil
    ctx.verify_mode     = OpenSSL::SSL::VERIFY_NONE
    # ctx.verify_depth    = nil
    # ctx.verify_callback = nil
    # ctx.cert_store      = nil
    ctx
  end
  
  def initialize(port)
    # setup_certificate
    tcpsocket = TCPServer.new("127.0.0.1", port)
    # tcpsocket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
    ctx = setup_ssl_context
    ssl = OpenSSL::SSL::SSLServer.new(tcpsocket, ctx)
    # ssl = OpenSSL::SSL::SSLSocket.new(tcpsocket, ctx)        
    # puts "setup"
    # ssl.sync_close = true
    # ssl.sync = true
    # ssl.connect
    # puts "Connected"
    
    # @sslsocket = ssl
    
    @acceptor = Thread.new do
      begin
        while true
            # client = @sslsocket
            client = ssl.accept
            
            # puts "accepted"

            while read_something = client.readline
              puts "server reads: #{read_something.size}" 
              client.write(read_something)
            end
            
        end
      rescue => e
        puts "exception: " + e.inspect
        puts e.backtrace.join("\n")
      end
    end
    
  end
    
end

sslserver = SimpleSSLServer.new(12343)
puts "server started"
Thread.stop