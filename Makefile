# Gapless Agent Runtime build environment.

REPOS_DIR ?= repos
TOOLS_DIR := $(REPOS_DIR)/tools
APPS_DIR := $(REPOS_DIR)/apps

GAR_TOOLS_URL ?= https://github.com/ThousandsOfTies/gar-tools.git
EMBEDDED_APP_URL ?= https://github.com/ThousandsOfTies/embedded-poc-app.git
GAR_VIBE_UI_URL ?= https://github.com/ThousandsOfTies/gar-vibe-ui.git

GAR_TOOLS_REPO ?= $(TOOLS_DIR)/gar-tools
EMBEDDED_APP_REPO ?= $(APPS_DIR)/embedded-poc-app
GAR_VIBE_UI_REPO ?= $(APPS_DIR)/gar-vibe-ui

GAR_TOOLS_RUNTIME := $(GAR_TOOLS_REPO)/targets/linux-device/runtime
M5STICKC_CLIENT := $(GAR_VIBE_UI_REPO)/vibe-remote/m5stickc-client
PIO_ENV ?= m5stickc-plus2-vibe-min

ARTIFACT_ROOT ?= artifacts/from-codespace
ARTIFACT_FILES := $(ARTIFACT_ROOT)/files

.PHONY: all setup sync build linux-tools linux-app m5stickc artifacts clean check-repos check-linux-repos check-m5-repo check-tools

all: artifacts

setup:
	scripts/ensure-repo.sh "$(GAR_TOOLS_URL)" "$(GAR_TOOLS_REPO)"
	scripts/ensure-repo.sh "$(EMBEDDED_APP_URL)" "$(EMBEDDED_APP_REPO)"
	scripts/ensure-repo.sh "$(GAR_VIBE_UI_URL)" "$(GAR_VIBE_UI_REPO)"

sync: setup
	scripts/sync-repo.sh "$(GAR_TOOLS_REPO)"
	scripts/sync-repo.sh "$(EMBEDDED_APP_REPO)"
	scripts/sync-repo.sh "$(GAR_VIBE_UI_REPO)"

check-repos: check-linux-repos check-m5-repo

check-linux-repos:
	@test -f "$(GAR_TOOLS_REPO)/Makefile" || { echo "missing gar-tools repo: $(GAR_TOOLS_REPO); run make setup"; exit 1; }
	@test -f "$(EMBEDDED_APP_REPO)/Makefile" || { echo "missing embedded-poc-app repo: $(EMBEDDED_APP_REPO); run make setup"; exit 1; }

check-m5-repo:
	@test -f "$(M5STICKC_CLIENT)/Makefile" || { echo "missing M5StickC client: $(M5STICKC_CLIENT); run make setup"; exit 1; }

check-tools:
	@command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || { echo "missing aarch64-linux-gnu-gcc; run scripts/post-create.sh or build in Codespaces"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "missing python3"; exit 1; }

linux-tools: setup check-linux-repos check-tools
	$(MAKE) -C "$(GAR_TOOLS_REPO)"

linux-app: setup check-linux-repos check-tools
	$(MAKE) -C "$(EMBEDDED_APP_REPO)"

build: linux-tools linux-app

m5stickc: setup check-m5-repo
	PATH="$(HOME)/.venvs/platformio/bin:$(PATH)" $(MAKE) -C "$(M5STICKC_CLIENT)" vm-package PIO_ENV="$(PIO_ENV)"

artifacts: build
	rm -rf "$(ARTIFACT_ROOT)"
	mkdir -p "$(ARTIFACT_FILES)"
	cp "$(EMBEDDED_APP_REPO)/app/sensor_demo" "$(ARTIFACT_FILES)/sensor_demo"
	cp "$(GAR_TOOLS_RUNTIME)/i2c-stub/cuse_i2c" "$(ARTIFACT_FILES)/cuse_i2c"
	cp "$(GAR_TOOLS_RUNTIME)/spi-stub/cuse_spi" "$(ARTIFACT_FILES)/cuse_spi"
	cp -R "$(GAR_TOOLS_RUNTIME)/web-bridge" "$(ARTIFACT_FILES)/web-bridge"
	python3 scripts/write_artifact_manifest.py "$(ARTIFACT_ROOT)"
	@echo "Wrote artifact bundle: $(ARTIFACT_ROOT)"

clean:
	@test ! -f "$(GAR_TOOLS_REPO)/Makefile" || $(MAKE) -C "$(GAR_TOOLS_REPO)" clean
	@test ! -f "$(EMBEDDED_APP_REPO)/Makefile" || $(MAKE) -C "$(EMBEDDED_APP_REPO)" clean
	rm -rf "$(ARTIFACT_ROOT)"
