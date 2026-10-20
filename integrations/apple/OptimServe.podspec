Pod::Spec.new do |s|
  s.name = 'OptimServe'
  s.version = '0.1.0'
  s.summary = 'OptimServe authorized peer delivery for native players.'
  s.homepage = 'https://p2p.optimserve.agency'
  s.author = 'OptimServe'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.source = { :http => 'https://p2p.optimserve.agency/sdk/apple/optimserve-apple-0.1.0.zip' }
  s.source_files = 'Sources/OptimServe/**/*.swift'
  s.vendored_frameworks = 'Vendor/SwarmCloudKit.xcframework', 'Vendor/datachannel_wrapper.xcframework'
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.7'
  s.frameworks = 'Foundation', 'AVFoundation', 'Network'
end
