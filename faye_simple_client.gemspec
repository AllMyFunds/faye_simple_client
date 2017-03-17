# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'faye_simple_client/version'

Gem::Specification.new do |spec|
  spec.name          = "faye_simple_client"
  spec.version       = FayeSimpleClient::VERSION
  spec.authors       = ["Wayne Robinson"]
  spec.email         = ["wayne.robinson@investmentlink.com.au"]

  spec.summary       = %q{Simple client for Faye.}
  spec.description   = %q{Simple client for Faye. Currently only supports publishing operations.}
  spec.homepage      = "https://github.com/AllMyFunds/faye_simple_client"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_dependency "faraday"
  spec.add_dependency "faraday_middleware"
  spec.add_dependency "faraday_connection_pool"
  spec.add_dependency "httpclient"
end
