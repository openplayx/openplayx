.PHONY: help ios-devices ios-build ios-install

# iOS device to install on: UDID or name as shown by `make ios-devices`.
# Empty picks the only connected iPhone/iPad; with several, set it explicitly:
#   make ios-install IOS_DEVICE=00008110-000410C23C2A401E
IOS_DEVICE ?=
IOS_APP := build/ios/iphoneos/Runner.app

help:
	@echo "make ios-devices                 List connected iOS devices"
	@echo "make ios-build                   Build a signed release Runner.app"
	@echo "make ios-install [IOS_DEVICE=…]  Build release and install it on a device"

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
