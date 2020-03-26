#
# Be sure to run `pod lib lint YMHTTP.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YMHTTP'
  s.version          = '1.0.0-beta.1'
  s.summary          = '一个基于 libcurl 的 IO 多路复用 HTTP 框架'
  s.homepage         = 'https://github.com/zymxxxs/YMHTTP'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zymxxxs' => 'zymxxxs@gmail.com' }
  s.source           = { :git => 'https://github.com/zymxxxs/YMHTTP.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'YMHTTP/**/*.{h,m}'
  s.public_header_files = 'YMHTTP/*.h'
  s.exclude_files = 'YMHTTP/libcurl/**/*.h'
  
  s.subspec 'libcurl' do |ss|
      ss.source_files = 'YMHTTP/libcurl/**/*.h'
      ss.private_header_files = 'YMHTTP/libcurl/**/*.h'
      ss.vendored_libraries = 'YMHTTP/libcurl/libcurl.a'
      ss.ios.library = 'z'
  end
  
end
