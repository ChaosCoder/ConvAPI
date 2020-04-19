Pod::Spec.new do |s|

  s.name          = "ConvAPI"
  s.version       = "1.0.0"
  s.summary       = "Easy HTTP requests against REST-style APIs with codable JSON bodies"
  s.description   = <<-DESC
                    ConvAPI allows easy HTTP requests in Swift against REST-style APIs with JSON formatting by supporting codable bodies and promised responses.
                    DESC

  s.homepage      = "https://github.com/ChaosCoder/ConvAPI"
  s.license       = { :type => 'MIT', :file => 'LICENSE.md'}
  s.author                = { "Andreas Ganske" => "info@chaosspace.de" }
  s.ios.deployment_target = "10.0"
  s.source        = { :git => "https://github.com/ChaosCoder/ConvAPI.git", :tag => s.version }
  s.source_files  = "ConvAPI", "ConvAPI/**/*.swift"
  s.swift_version = "5.0"
  s.dependency "PromiseKit", "~> 6.8"

end
