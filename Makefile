PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
CONFIGURATION ?= release
BUILD_DIR := .build/$(CONFIGURATION)
CLANG_MODULE_CACHE := $(CURDIR)/.build/clang-module-cache
SLEEPD := $(BUILD_DIR)/sleepd
SLEEPCTL := $(BUILD_DIR)/sleepctl
INSTALLED_SLEEPD := $(BINDIR)/sleepd
INSTALLED_SLEEPCTL := $(BINDIR)/sleepctl
LAUNCH_AGENT := $(HOME)/Library/LaunchAgents/com.takeiteasy.SleepDaemon.plist

export CLANG_MODULE_CACHE_PATH := $(CLANG_MODULE_CACHE)

.PHONY: build test install uninstall clean

build:
	swift build --disable-sandbox -c $(CONFIGURATION)

test:
	swift test --disable-sandbox

install: build
	mkdir -p "$(BINDIR)"
	cp "$(SLEEPD)" "$(INSTALLED_SLEEPD)"
	cp "$(SLEEPCTL)" "$(INSTALLED_SLEEPCTL)"
	chmod 755 "$(INSTALLED_SLEEPD)" "$(INSTALLED_SLEEPCTL)"
	"$(INSTALLED_SLEEPCTL)" daemon install --daemon-path "$(INSTALLED_SLEEPD)"
	"$(INSTALLED_SLEEPCTL)" daemon start

uninstall:
	@if [ -x "$(INSTALLED_SLEEPCTL)" ]; then \
		"$(INSTALLED_SLEEPCTL)" daemon uninstall; \
	else \
		launchctl bootout "gui/$$(id -u)/com.takeiteasy.SleepDaemon" 2>/dev/null || true; \
		rm -f "$(LAUNCH_AGENT)"; \
	fi
	rm -f "$(INSTALLED_SLEEPD)" "$(INSTALLED_SLEEPCTL)"

clean:
	swift package clean
