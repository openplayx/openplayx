Pod::Spec.new do |s|
  s.name = 'vlc_player_tvos'
  s.version = '0.0.1'
  s.summary = 'OpenPlayX VLC playback for Apple TV'
  s.homepage = 'https://github.com/openplayx/openplayx'
  s.license = { :file => '../LICENSE' }
  s.author = 'OpenPlayX'
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*.swift'
  s.resource_bundles = {'vlc_player_tvos_privacy' => ['Classes/PrivacyInfo.xcprivacy']}
  s.dependency 'TVVLCKit', '3.7.3'
  s.platform = :tvos, '13.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/../Flutter"'
  }
end
