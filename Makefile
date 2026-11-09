.PHONY: all build install clean

all: build

build:
	./Scripts/build.sh

install: build
	@echo "==> Installing to /Applications/Local LLM Manager.app..."
	rm -rf "/Applications/Local LLM Manager.app"
	cp -R "build/Local LLM Manager.app" "/Applications/"
	@echo "==> Installed successfully."

clean:
	rm -rf build .build
