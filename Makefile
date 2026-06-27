# Gapless Agent Runtime build environment.

GAR_TOOLS_REPO := $(if $(wildcard repos/gar-tools/Makefile),repos/gar-tools,../gar-tools)
EMBEDDED_APP_REPO := $(if $(wildcard repos/embedded-poc-app/Makefile),repos/embedded-poc-app,../embedded-poc-app)
GAR_TOOLS_RUNTIME := $(GAR_TOOLS_REPO)/targets/linux-device/runtime
ARTIFACT_ROOT ?= artifacts/from-codespace
ARTIFACT_FILES := $(ARTIFACT_ROOT)/files

.PHONY: all build artifacts clean check-repos check-tools

all: build artifacts

check-repos:
	@test -f "$(GAR_TOOLS_REPO)/Makefile" || { echo "missing gar-tools repo: $(GAR_TOOLS_REPO)"; exit 1; }
	@test -f "$(EMBEDDED_APP_REPO)/Makefile" || { echo "missing embedded-poc-app repo: $(EMBEDDED_APP_REPO)"; exit 1; }

check-tools:
	@command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || { echo "missing aarch64-linux-gnu-gcc; run scripts/post-create.sh or build in Codespaces"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "missing python3"; exit 1; }

build: check-repos check-tools
	$(MAKE) -C "$(GAR_TOOLS_REPO)"
	$(MAKE) -C "$(EMBEDDED_APP_REPO)"

artifacts: build
	rm -rf "$(ARTIFACT_ROOT)"
	mkdir -p "$(ARTIFACT_FILES)"
	cp "$(EMBEDDED_APP_REPO)/app/sensor_demo" "$(ARTIFACT_FILES)/sensor_demo"
	cp "$(GAR_TOOLS_RUNTIME)/i2c-stub/cuse_i2c" "$(ARTIFACT_FILES)/cuse_i2c"
	cp "$(GAR_TOOLS_RUNTIME)/spi-stub/cuse_spi" "$(ARTIFACT_FILES)/cuse_spi"
	cp -R "$(GAR_TOOLS_RUNTIME)/web-bridge" "$(ARTIFACT_FILES)/web-bridge"
	python3 scripts/write_artifact_manifest.py "$(ARTIFACT_ROOT)"
	@echo "Wrote artifact bundle: $(ARTIFACT_ROOT)"

clean: check-repos
	$(MAKE) -C "$(GAR_TOOLS_REPO)" clean
	$(MAKE) -C "$(EMBEDDED_APP_REPO)" clean
	rm -rf "$(ARTIFACT_ROOT)"
