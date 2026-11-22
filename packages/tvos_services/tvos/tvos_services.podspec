Pod::Spec.new do |s|
 s.name='tvos_services'
 s.version='0.0.1'
 s.summary='Native Apple TV services'
 s.homepage='https://github.com/openplayx/openplayx'
 s.author='OpenPlayX'
 s.license={:type=>'MIT'}
 s.source={:path=>'.'}
 s.source_files='Classes/**/*.swift'
 s.resource_bundles={'OpenPlayXModels'=>['Resources/ggml-tiny.bin','Resources/ggml-tiny-encoder.mlmodelc','Resources/Licenses']}
 s.platform=:tvos,'17.0'
 s.swift_version='5.0'
 s.frameworks='AuthenticationServices','AVKit','AVFoundation','BackgroundTasks'
 s.pod_target_xcconfig={'DEFINES_MODULE'=>'YES','FRAMEWORK_SEARCH_PATHS'=>'$(inherited) "${PODS_ROOT}/../Flutter"'}
end
