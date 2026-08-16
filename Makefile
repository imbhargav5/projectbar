.PHONY: build test app run clean

build:
	swift build

test:
	swift test

app:
	./Scripts/package_app.sh release

run:
	./Scripts/run_app.sh

clean:
	swift package clean
