.PHONY: setup run-backend build-app run-all clean

setup:
	cd backend && chmod +x setup.sh && ./setup.sh

run-backend:
	cd backend && source venv/bin/activate && python findmyvoice_core.py

build-app:
	xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice -configuration Release build

run-all:
	make run-backend &
	sleep 2
	make build-app && open "$$(xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$NF}')/FindMyVoice.app"

clean:
	xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice clean
	rm -rf build/
