Pod::Spec.new do |s|
  s.name = 'OptimServeReactNative'; s.version = '0.1.0'
  s.summary = 'OptimServe session bridge for React Native'
  s.homepage = 'https://p2p.optimserve.agency'; s.author = 'OptimServe'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.source = { :http => 'https://p2p.optimserve.agency/sdk/native/optimserve-react-native-0.1.0.tgz' }
  s.source_files = 'ios/**/*.{swift,m}'
  s.ios.deployment_target = '13.0'; s.tvos.deployment_target = '13.0'; s.swift_version = '5.7'
  s.dependency 'React-Core'; s.dependency 'OptimServe', '0.1.0'
end
