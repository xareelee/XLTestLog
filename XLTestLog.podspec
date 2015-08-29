Pod::Spec.new do |s|
  s.name         = 'XLTestLog'
  s.version      = '1.0.0'
  s.license      = 'MIT'
  s.summary      = 'Styling and coloring your XCTest logs on Xcode Console.'
  s.description  = 'XLTestLog is a lightweight library to style and color your XCTest logs on Xcode console for more readability.'
  s.homepage     = 'https://github.com/xareelee/XLTestLog'
  s.authors      = { 'Kang-Yu Xaree Lee' => 'xareelee@gmail.com' }
  s.source       = { :git => "https://github.com/xareelee/XLTestLog.git", :tag => s.version.to_s, :submodules =>  true }
  
  s.requires_arc = true  
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'

  s.frameworks = 'Foundation', 'XCTest'

  s.source_files = 'XLTestLog/*.{h,m}'

end
