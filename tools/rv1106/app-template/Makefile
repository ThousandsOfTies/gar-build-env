BUILD_DIR ?= build
GAR_TOOLS_ROOT ?= ../../../sources/gar-tools
TARGET_ROOT ?= $(GAR_TOOLS_ROOT)/targets/luckfox-rv1106
TOOLCHAIN_FILE ?= $(TARGET_ROOT)/toolchain/rv1106-buildroot-toolchain.cmake
CMAKE_BUILD_TYPE ?= Release
CMAKE_GENERATOR ?= Ninja
DEPLOY_SCRIPT ?= $(TARGET_ROOT)/scripts/deploy_ssh.sh

.PHONY: all configure build install clean deploy

all: build

configure:
	cmake -S . -B $(BUILD_DIR) -G "$(CMAKE_GENERATOR)" \
		-DCMAKE_TOOLCHAIN_FILE=$(TOOLCHAIN_FILE) \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)

build: configure
	cmake --build $(BUILD_DIR) -- -j

install: build
	cmake --install $(BUILD_DIR) --prefix $(PWD)/$(BUILD_DIR)/stage

deploy: build
	"$(DEPLOY_SCRIPT)" "$(PWD)/$(BUILD_DIR)/gar_luckfox_streamer"

clean:
	rm -rf $(BUILD_DIR)
