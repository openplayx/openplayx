Pod::Spec.new do |s|
  s.name = 'OpenPlayXRemote'
  s.version = '0.1.0'
  s.summary = 'Application-scoped sing-box transport bridge'
  s.homepage = 'https://github.com/openplayx/openplayx'
  s.license = { :type => 'GPL-3.0-or-later', :file => 'LICENSE' }
  s.author = 'OpenPlayX'
  s.source = { :git => 'https://github.com/openplayx/openplayx.git' }
  s.source_files = 'anchor.c'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.static_framework = true
  s.frameworks = 'Security', 'SystemConfiguration', 'CoreFoundation', 'Network'
  s.libraries = 'resolv'
  s.script_phase = {
    :name => 'Build pinned sing-box bridge',
    :script => 'bash "${PODS_TARGET_SRCROOT}/build_apple.sh"',
    :execution_position => :before_compile,
    :input_files => ['${PODS_TARGET_SRCROOT}/main.go', '${PODS_TARGET_SRCROOT}/go.mod', '${PODS_TARGET_SRCROOT}/go.sum', '${PODS_TARGET_SRCROOT}/build_apple.sh'],
    :output_files => ['${PODS_CONFIGURATION_BUILD_DIR}/libopenplayx_remote.a']
  }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -Wl,-force_load,"${PODS_CONFIGURATION_BUILD_DIR}/libopenplayx_remote.a" -Wl,-u,_opx_remote_start -Wl,-u,_opx_remote_stop -Wl,-u,_opx_remote_alloc -Wl,-u,_opx_remote_free -Wl,-export_dynamic' }
end
