Pod::Spec.new do |s|

  s.name          = "JSONAPI"
  s.version       = "0.2.2"
  s.summary       = "Simple JSON API class to request codable resources."
  s.description   = <<-DESC
                      Simple JSON API class. It allows to request a JSON API over HTTP with simple methods.
                    DESC

  s.homepage      = "https://github.com/ChaosCoder/JSONAPI"
  s.license       = { :type => 'MIT', :file => 'LICENSE.md'}
  s.author                = { "Andreas Ganske" => "info@chaosspace.de" }
  s.ios.deployment_target = "10.0"
  s.source        = { :git => "https://github.com/ChaosCoder/JSONAPI.git", :tag => s.version }
  s.source_files  = "JSONAPI", "JSONAPI/**/*.swift"
  s.swift_version = "4.0"
  s.dependency "Result", "~> 3.0"

end
