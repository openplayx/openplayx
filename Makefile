.PHONY: help ios-devices ios-build ios-install ios-install-seeded seed seed-check seed-push run-seeded \
	integration-defines integration-ollama integration-macos integration-ios integration-android

# iOS device to install on: UDID or name as shown by `make ios-devices`.
# Empty picks the only connected iPhone/iPad; with several, set it explicitly:
#   make ios-install IOS_DEVICE=00008110-000410C23C2A401E
IOS_DEVICE ?=
IOS_APP := build/ios/iphoneos/Runner.app

# Debug configuration seed (docs/debug_seed.md): a JSON template plus .env.
SEED ?= debug-seed.json
SEED_ENV ?= .env
# seed-push target: macos | ios-sim | android | linux | windows
PLATFORM ?=
# run-seeded: any `flutter run -d` device id (empty: Flutter's default).
DEVICE ?=

# Integration tests (integration_test/README.md): live services are required.
IT_DEFINES := build/integration-defines.json
# Small local model for the assistant movie flow, with room for every tool.
OLLAMA_BASE ?= qwen3.5:4b-mlx
OLLAMA_MODEL ?= openplayx-it
OLLAMA_CTX ?= 32768
# integration-ios / integration-android device ids.
IOS_SIM ?= $(shell xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-F-]{36}' | head -1)
ANDROID_DEVICE ?= emulator-5554
IT_MOBILE := integration_test/playback_test.dart integration_test/ffmpeg_bridge_test.dart \
	integration_test/whisper_bridge_test.dart integration_test/source_storage_test.dart \
	integration_test/sources_test.dart integration_test/mobile_ai_playback_test.dart \
	integration_test/metadata_background_test.dart
IT_DRIVE = flutter drive --driver=test_driver/integration_test.dart -d macos \
	--dart-define-from-file=$(IT_DEFINES) --target=integration_test/$(1)

help:
	@echo "make ios-devices                 List connected iOS devices"
	@echo "make ios-build                   Build a signed release Runner.app"
	@echo "make ios-install [IOS_DEVICE=…]  Build release and install it on a device"
	@echo "make ios-install-seeded [IOS_DEVICE=…]  Build profile with the seed and install it"
	@echo "make seed                        Fill $(SEED) from $(SEED_ENV) into build/debug-seed.json"
	@echo "make seed-check                  Check every seed item against the real services"
	@echo "make seed-push PLATFORM=…        Put the seed into the installed debug App (next start)"
	@echo "make run-seeded [DEVICE=…]       flutter run with the seed (any platform)"
	@echo "make integration-defines         Write $(IT_DEFINES) (test VM, movie share, Ollama, whisper)"
	@echo "make integration-ollama          Create the Ollama test model $(OLLAMA_MODEL) from $(OLLAMA_BASE)"
	@echo "make integration-macos           All integration tests on macOS (live services required)"
	@echo "make integration-ios [IOS_SIM=…] Mobile integration tests on an iOS simulator"
	@echo "make integration-android [ANDROID_DEVICE=…]  Mobile integration tests on Android"

ios-devices:
	@xcrun devicectl list devices

# Release and profile (AOT) builds launch from the home screen without
# `flutter run` attached; debug builds on iOS 14+ only start while the tool is
# connected. build/ios is removed first: reusing it across build modes leaves
# Flutter.framework modified after signing, and the device refuses to install.
ios-build:
	rm -rf build/ios
	flutter build ios --release

ios-install: ios-build
	@$(ios_install_app)

# The seed is compiled in (a device has no writable spot for seed-push), so
# this is a profile build: release builds ignore the seed. The App carries the
# seed's credentials; keep it on your own devices.
ios-install-seeded: seed
	rm -rf build/ios
	flutter build ios --profile "$$(dart run tool/debug_seed.dart define)"
	@$(ios_install_app)

# Installs $(IOS_APP) on $(IOS_DEVICE), or on the only paired iPhone/iPad.
define ios_install_app
device="$(IOS_DEVICE)"; \
	if [ -z "$$device" ]; then \
	  json=$$(mktemp); \
	  xcrun devicectl list devices --json-output "$$json" >/dev/null || exit 1; \
	  device=$$(python3 -I -c 'import json,sys; \
d=[x for x in json.load(open(sys.argv[1]))["result"]["devices"] \
   if x.get("hardwareProperties",{}).get("reality")=="physical" \
   and x.get("connectionProperties",{}).get("pairingState")=="paired" \
   and x.get("hardwareProperties",{}).get("platform")=="iOS"]; \
print(d[0]["hardwareProperties"]["udid"] if len(d)==1 else "", end=""); \
sys.exit(0 if len(d)==1 else len(d) or 99)' "$$json"); status=$$?; \
	  rm -f "$$json"; \
	  if [ $$status -ne 0 ]; then \
	    if [ $$status -eq 99 ]; then echo "No connected iOS device." >&2; \
	    else echo "Several iOS devices connected; choose one with IOS_DEVICE=<UDID>:" >&2; \
	      xcrun devicectl list devices >&2; fi; \
	    exit 1; \
	  fi; \
	fi; \
	echo "Installing $(IOS_APP) on $$device"; \
	xcrun devicectl device install app --device "$$device" "$(IOS_APP)"
endef

seed:
	dart run tool/debug_seed.dart build --seed $(SEED) --env $(SEED_ENV)

# Imports the seed into a throwaway configuration and checks every item
# against the real services (browse, MCP handshake, TMDB, model API).
seed-check: seed
	flutter test tool/debug_seed_check_test.dart --reporter expanded

seed-push: seed
	@test -n "$(PLATFORM)" || { echo "Set PLATFORM=macos|ios-sim|android|linux|windows" >&2; exit 1; }
	dart run tool/debug_seed.dart push --platform $(PLATFORM)

run-seeded: seed
	flutter run $(if $(DEVICE),-d $(DEVICE)) "$$(dart run tool/debug_seed.dart define)"

integration-defines:
	python3 tool/integration/defines.py

# The base model with a context window that holds the App's tool schemas.
integration-ollama:
	printf 'FROM $(OLLAMA_BASE)\nPARAMETER num_ctx $(OLLAMA_CTX)\n' | ollama create $(OLLAMA_MODEL) -f -

integration-macos: integration-defines
	flutter test -d macos --dart-define-from-file=$(IT_DEFINES) $(filter-out \
		integration_test/metadata_background_test.dart integration_test/mobile_ai_playback_test.dart,$(IT_MOBILE)) \
		integration_test/ui_screenshots_test.dart
	$(call IT_DRIVE,player_window_test.dart)
	$(call IT_DRIVE,assistant_movie_flow_test.dart)

integration-ios: integration-defines
	@test -n "$(IOS_SIM)" || { echo "Boot an iOS simulator or set IOS_SIM=<udid>" >&2; exit 1; }
	flutter test -d $(IOS_SIM) --dart-define-from-file=$(IT_DEFINES) $(IT_MOBILE)

integration-android: integration-defines
	flutter test -d $(ANDROID_DEVICE) --dart-define-from-file=$(IT_DEFINES) \
		--dart-define=OPENPLAYX_METADATA_DATABASE=metadata_workmanager_test.sqlite3 $(IT_MOBILE)
