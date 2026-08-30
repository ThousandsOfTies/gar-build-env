# Gapless Agent Runtime build environment.

PRODUCT_BUILD_SCRIPT ?= scripts/product-build.sh
PRODUCT_ARTIFACTS_SCRIPT ?= scripts/product-artifacts.sh
PRODUCT_CLEAN_SCRIPT ?= scripts/product-target-build.sh
DEPLOYMENT ?= frdm-imx91s

ARTIFACT_ROOT ?= artifacts/from-codespace
BUILD_IMAGE ?= gar-build-env:latest

.PHONY: all setup sync build artifacts check clean

all: artifacts

setup:
	scripts/setup-product-branch.sh

sync:
	@if [ -f .gitmodules ]; then \
		git submodule foreach --recursive 'branch=$$(git branch --show-current); if [ -n "$$branch" ]; then git pull --ff-only; else echo "detached HEAD; skip pull"; fi'; \
	fi

build:
	@if [ -x "$(PRODUCT_BUILD_SCRIPT)" ]; then \
		"$(PRODUCT_BUILD_SCRIPT)"; \
	else \
		echo "No product build script: $(PRODUCT_BUILD_SCRIPT)"; \
	fi

artifacts: build
	@if [ -x "$(PRODUCT_ARTIFACTS_SCRIPT)" ]; then \
		"$(PRODUCT_ARTIFACTS_SCRIPT)" "$(ARTIFACT_ROOT)"; \
	else \
		echo "No product artifacts script: $(PRODUCT_ARTIFACTS_SCRIPT)"; \
	fi

check:
	bash -n scripts/*.sh scripts/targets/*/*.sh \
		scripts/targets/frdm-imx91s/device-tree/*.sh \
		scripts/targets/frdm-imx91s/provisioning/uuu/*.sh \
		config/frdm-imx91s.env.example config/imx91s-uuu.env.example
	sh -n scripts/targets/luckfox-rk3506/configure-target \
		scripts/targets/luckfox-rk3506/health
	scripts/package-target.sh --deployment "$(DEPLOYMENT)" --describe >/dev/null
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
	node --test tests/servo-model.test.mjs
	tests/test_product_target_clean.sh
	tests/test_luckfox_target_clean.sh
	@if command -v cc >/dev/null 2>&1; then \
		$(MAKE) -C sources/gar-servo-pet check; \
	elif command -v docker >/dev/null 2>&1 && \
	     docker image inspect "$(BUILD_IMAGE)" >/dev/null 2>&1; then \
		docker run --rm --pull=never \
			--user "$$(id -u):$$(id -g)" \
			-v "$(CURDIR):/workspace" \
			-w /workspace/sources/gar-servo-pet \
			"$(BUILD_IMAGE)" make check; \
	else \
		echo "No host C compiler and no local $(BUILD_IMAGE) fallback" >&2; \
		exit 1; \
	fi
	sources/gar-servo-pet/build/host/gar-servoctl \
		--i2c-config hardware/profiles/frdm-imx91s/i2c.csv \
		--servo-config hardware/servo-calibration.csv validate

clean:
	@if [ -x "$(PRODUCT_CLEAN_SCRIPT)" ]; then \
		GAR_DEPLOYMENT="$(DEPLOYMENT)" GAR_ARTIFACT_ROOT="$(ARTIFACT_ROOT)" \
			"$(PRODUCT_CLEAN_SCRIPT)" clean; \
	fi
