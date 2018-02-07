Pod::Spec.new do |s|
  s.name             = 'NetworkService'
  s.version          = '1.0.0'
  s.summary          = 'A simple NetworkService.'
  s.description      = 'A simple NetworkService.'
  s.homepage         = 'https://github.com/TBXark/NetworkService'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'TBXark' => 'tbxark@outlook.com' }
  s.source           = { :git => 'https://github.com/TBXark/NetworkService.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'NetworkService/Classes/**/*.swift'
  s.dependency 'Alamofire' , '~> 4.5'
  s.dependency 'RxSwift'   , '~> 4.0'
  s.dependency 'RxCocoa'   , '~> 4.0'
  s.dependency 'TKJsonMapper'
end
