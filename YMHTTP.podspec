#
# Be sure to run `pod lib lint YMHTTP.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YMHTTP'
  s.version          = '1.0.0'
  s.summary          = 'A short description of YMHTTP.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/zymxxxs/YMHTTP'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zymxxxs' => 'zymxxxs@gmail.com' }
  s.source           = { :git => 'https://github.com/zymxxxs/YMHTTP.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'YMHTTP/Classes/*.{h,m}'

  s.subspec 'Core' do |ss|
    ss.source_files = 'YMHTTP/Classes/core/**/*.{h,m}'
    ss.dependency 'YMHTTP/Curl'
  end
  
  s.subspec 'Curl' do |ss|
      ss.source_files = 'YMHTTP/Classes/curl/**/*.{h,m}'
      ss.dependency 'YMHTTP/libcurl'
  end
  
  s.subspec 'libcurl' do |ss|
      ss.source_files = 'YMHTTP/Classes/libcurl/**/*.h'
      ss.vendored_libraries = 'YMHTTP/Classes/libcurl/libcurl.a'
      ss.ios.library = 'z'
  end
  
end
