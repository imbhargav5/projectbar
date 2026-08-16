.PHONY: build test app install install-startup run clean

build:
	swift build

test:
	swift test

app:
	./Scripts/package_app.sh release

install:
	./Scripts/install_app.sh

install-startup:
	PROJECTBAR_ENABLE_LAUNCH_AT_LOGIN=1 ./Scripts/install_app.sh

run:
	./Scripts/run_app.sh

clean:
	swift package clean
