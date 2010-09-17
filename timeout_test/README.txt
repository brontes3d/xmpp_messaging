run:
	ruby echo_server.rb
and:
	ruby socket_timeout_test.rb
	
To diagnose the timeout on OpenSSL::SSL::SSLSocket.sysread