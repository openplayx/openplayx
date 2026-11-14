.PHONY: help ios-devices ios-build ios-install seed seed-check seed-push run-seeded

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

help:
	@echo "make ios-devices                 List connected iOS devices"
	@echo "make ios-build                   Build a signed release Runner.app"
	@echo "make ios-install [IOS_DEVICE=…]  Build release and install it on a device"
	@echo "make seed                        Fill $(SEED) from $(SEED_ENV) into build/debug-seed.json"
	@echo "make seed-check                  Check every seed item against the real services"
	@echo "make seed-push PLATFORM=…        Put the seed into the installed debug App (next start)"
	@echo "make run-seeded [DEVICE=…]       flutter run with the seed (any platform)"

ios-devices:
	@xcrun devicectl list devices

# Release (AOT) builds launch from the home screen without `flutter run`
# attached; debug builds on iOS 14+ only start while the tool is connected.
ios-build:
	flutter build ios --release

ios-install: ios-build
	@device="$(IOS_DEVICE)"; \
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
