Pod::Spec.new do |s|
  s.name             = 'CodableDB'
  s.version          = '0.1.1'
  s.summary          = 'Use CodableDB to encode and decode database objects using the Codable protocol.'

  s.description      = <<-DESC
Codable enables to en- & decode database objects using the Codable protocol. It serves as a wrapper to the SQLite3 framework by Apple, Inc. 
                      DESC

  s.homepage         = 'https://github.com/pauljohanneskraft/CodableDB'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'pauljohanneskraft' => 'pauljohanneskraft@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/pauljohanneskraft/CodableDB.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.swift_version = '4.2'

  s.source_files = 'CodableDB/Classes/**/*'
end
