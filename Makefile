.PHONY: setup run-backend build-app install run-all clean

setup:
	cd backend && chmod +x setup.sh && ./setup.sh

run-backend:
	cd backend && source venv/bin/activate && python findmyvoice_core.py

build-app:
	xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice -configuration Release build

install:
	xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice -configuration Release build
	osascript -e 'tell application "FindMyVoice" to quit' 2>/dev/null; sleep 1; true
	$(eval BUILD_DIR := $(shell xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$NF}'))
	# Bundle backend into app Resources
	mkdir -p "$(BUILD_DIR)/FindMyVoice.app/Contents/Resources/backend"
	cp backend/findmyvoice_core.py "$(BUILD_DIR)/FindMyVoice.app/Contents/Resources/backend/"
	cp backend/requirements.txt "$(BUILD_DIR)/FindMyVoice.app/Contents/Resources/backend/"
	cp backend/setup.sh "$(BUILD_DIR)/FindMyVoice.app/Contents/Resources/backend/"
	test -d backend/venv && cp -R backend/venv "$(BUILD_DIR)/FindMyVoice.app/Contents/Resources/backend/venv" || true
	# Install to /Applications (remove old copy first to ensure clean replacement)
	rm -rf /Applications/FindMyVoice.app
	cp -R "$(BUILD_DIR)/FindMyVoice.app" /Applications/FindMyVoice.app
	open /Applications/FindMyVoice.app

run-all:
	make run-backend &
	sleep 2
	make build-app && open "$$(xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$NF}')/FindMyVoice.app"

clean:
	xcodebuild -project FindMyVoice.xcodeproj -scheme FindMyVoice clean
	rm -rf build/
