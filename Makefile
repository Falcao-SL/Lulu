.PHONY: all build install clean

all: build

build:
	./Scripts/build.sh

package:
	./Scripts/package-macos.sh

install: build
	@echo "==> Installing to /Applications/Lulu.app..."
	rm -rf "/Applications/Lulu.app"
	cp -R "build/Lulu.app" "/Applications/"
	@echo "==> Installed successfully."

clean:
	rm -rf build .build
