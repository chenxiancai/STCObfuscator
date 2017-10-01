Pod::Spec.new do |s|
  s.name         = 'STCObfuscator'
  s.summary      = 'Objective-C obfuscator for Mach-O executables, a runtime utility for obfuscating Objective-C class..'
  s.version      = '1.0.1'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.authors      = { 'chenxiancai' => 'chenxiancai@hotmail.com' }
  s.homepage     = 'https://github.com/chenxiancai/STCObfuscator'

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.7'

  s.source       = { :git => 'https://github.com/chenxiancai/STCObfuscator.git', :tag => s.version }
  
  s.source_files = "STCObfuscator/STCObfuscator/*.{h,m,c}"
  s.subspec 'Ahocorasick' do |ahocorasick|
    ahocorasick.source_files   = 'STCObfuscator/STCObfuscator/ahocorasick/*.{h,c}'                       
  end
  s.requires_arc = true
  
  s.frameworks = 'Foundation'

end
