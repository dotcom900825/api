require 'sinatra'

require 'rubygems'
require 'bundler'
require 'webrick'
require 'webrick/https'
require 'openssl'

Bundler.require

require './ipassstore_api_app'

CERT_PATH = '/Users/thomas/Desktop/rails/passbook/passbook_sinatra/.ssl'

webrick_options = {
        :Port               => 8443,
        :Logger             => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
        :DocumentRoot       => "/ruby/htdocs",
        :SSLEnable          => true,
        :SSLVerifyClient    => OpenSSL::SSL::VERIFY_NONE,
        :SSLCertificate     => OpenSSL::X509::Certificate.new(  File.open(File.join(CERT_PATH, "server.crt")).read),
        :SSLPrivateKey      => OpenSSL::PKey::RSA.new(          File.open(File.join(CERT_PATH, "server.key")).read),
        :SSLCertName        => [ [ "CN",WEBrick::Utils::getservername ] ]
}

Rack::Handler::WEBrick.run IpassstoreApiApp, webrick_options

