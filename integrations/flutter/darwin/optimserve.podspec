Pod::Spec.new do |s|
  s.name = 'optimserve'; s.version = '0.1.0'
  s.summary = 'OptimServe session bridge for Flutter'
  s.homepage = 'https://p2p.optimserve.agency'; s.author = 'OptimServe'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.source = { :path => '.' }; s.source_files = 'Classes/**/*.swift'
  s.ios.deployment_target = '13.0'; s.tvos.deployment_target = '13.0'; s.osx.deployment_target = '10.15'; s.swift_version = '5.7'
  s.ios.dependency 'Flutter'; s.tvos.dependency 'Flutter'; s.osx.dependency 'FlutterMacOS'; s.dependency 'OptimServe', '0.1.0'
end
