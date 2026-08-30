#!/usr/bin/env python3
"""Validate and compose a Product application with a physical Target Capsule."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SAFE_ID = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


class ProfileError(ValueError):
    """A deployment composition is malformed or internally inconsistent."""


def _load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise ProfileError(f"cannot read {label}: {path}: {error}") from error
    except json.JSONDecodeError as error:
        raise ProfileError(f"invalid {label} JSON: {path}: {error.msg}") from error
    if not isinstance(value, dict):
        raise ProfileError(f"{label} must be a JSON object: {path}")
    return value


def _exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise ProfileError(f"{label} fields differ: missing={missing}, extra={extra}")


def _safe_id(value: object, label: str) -> str:
    if not isinstance(value, str) or SAFE_ID.fullmatch(value) is None:
        raise ProfileError(f"{label} must match {SAFE_ID.pattern}")
    return value


def _safe_name(value: object, label: str) -> str:
    if not isinstance(value, str) or SAFE_NAME.fullmatch(value) is None:
        raise ProfileError(f"{label} must match {SAFE_NAME.pattern}")
    return value


def _relative_path(
    root: Path,
    value: object,
    label: str,
    *,
    must_exist: bool = True,
) -> Path:
    if not isinstance(value, str) or not value:
        raise ProfileError(f"{label} must be a non-empty relative path")
    pure = PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts:
        raise ProfileError(f"{label} must stay inside the Product repository: {value}")
    path = (root / Path(*pure.parts)).resolve(strict=False)
    try:
        path.relative_to(root)
    except ValueError as error:
        raise ProfileError(f"{label} resolves outside the Product repository: {value}") from error
    if must_exist and not path.is_file():
        raise ProfileError(f"{label} is missing: {value}")
    return path


def _application_manifest(path: Path) -> dict[str, Any]:
    manifest = _load_object(path, "application manifest")
    _exact_keys(manifest, {"schema_version", "id", "build", "runtime"}, "application manifest")
    if manifest["schema_version"] != 1:
        raise ProfileError("application manifest schema_version must be 1")
    app_id = _safe_id(manifest["id"], "application id")

    build = manifest["build"]
    if not isinstance(build, dict):
        raise ProfileError("application build must be an object")
    _exact_keys(build, {"system", "goal", "binary", "artifact_name"}, "application build")
    if build["system"] != "make":
        raise ProfileError("application build system must be make")
    _safe_name(build["goal"], "application build goal")
    _safe_name(build["artifact_name"], "application artifact_name")
    _relative_path(path.parent, build["binary"], "application binary", must_exist=False)

    runtime = manifest["runtime"]
    if not isinstance(runtime, dict):
        raise ProfileError("application runtime must be an object")
    _exact_keys(
        runtime,
        {"entrypoint", "readme", "install_dir", "configuration"},
        "application runtime",
    )
    runtime["entrypoint"] = _relative_path(
        path.parent, runtime["entrypoint"], "application entrypoint"
    ).relative_to(path.parent).as_posix()
    runtime["readme"] = _relative_path(
        path.parent, runtime["readme"], "application readme"
    ).relative_to(path.parent).as_posix()
    expected_install_dir = f"/opt/gar/apps/{app_id}"
    if runtime["install_dir"] != expected_install_dir:
        raise ProfileError(
            f"application install_dir must be {expected_install_dir}: {runtime['install_dir']}"
        )
    configuration = runtime["configuration"]
    if not isinstance(configuration, dict):
        raise ProfileError("application runtime.configuration must be an object")
    _exact_keys(
        configuration,
        {"i2c", "connections", "servo_calibration"},
        "application runtime.configuration",
    )
    destinations: set[str] = set()
    for name, value in configuration.items():
        destination = _relative_path(
            path.parent,
            value,
            f"application runtime.configuration.{name}",
            must_exist=False,
        ).relative_to(path.parent).as_posix()
        if destination == ".":
            raise ProfileError(
                f"application runtime.configuration.{name} must name a file"
            )
        if destination in destinations:
            raise ProfileError("application runtime configuration destinations must be unique")
        destinations.add(destination)
        configuration[name] = destination

    payload_destinations = [
        PurePosixPath(build["artifact_name"]),
        PurePosixPath(runtime["entrypoint"]),
        PurePosixPath("README.md"),
        *(PurePosixPath(destination) for destination in configuration.values()),
    ]
    for index, left in enumerate(payload_destinations):
        for right in payload_destinations[index + 1 :]:
            if left == right or left in right.parents or right in left.parents:
                raise ProfileError(
                    "application payload destinations overlap: "
                    f"{left.as_posix()} and {right.as_posix()}"
                )
    return manifest


def _binding(path: Path, product_id: str, target: str) -> dict[str, Any]:
    binding = _load_object(path, "hardware binding")
    _exact_keys(binding, {"schema_version", "product", "target", "interfaces"}, "hardware binding")
    if binding["schema_version"] != 1:
        raise ProfileError("hardware binding schema_version must be 1")
    if binding["product"] != product_id:
        raise ProfileError("hardware binding product does not match the deployment")
    if binding["target"] != target:
        raise ProfileError("hardware binding target does not match the deployment")
    interfaces = binding["interfaces"]
    if not isinstance(interfaces, list) or len(interfaces) != 1:
        raise ProfileError("deployment requires exactly one hardware interface")
    interface = interfaces[0]
    if not isinstance(interface, dict):
        raise ProfileError("hardware interface must be an object")
    _exact_keys(
        interface,
        {
            "id",
            "kind",
            "controller",
            "bus",
            "device",
            "address",
            "frequency_hz",
            "logic_voltage_v",
            "pins",
        },
        "hardware interface",
    )
    if interface["id"] != "servo-bus" or interface["kind"] != "i2c":
        raise ProfileError("hardware interface must define the servo-bus I2C interface")
    if not isinstance(interface["controller"], str) or not interface["controller"]:
        raise ProfileError("hardware interface controller must be a non-empty string")
    if type(interface["bus"]) is not int or interface["bus"] < 0:
        raise ProfileError("hardware interface bus must be a non-negative integer")
    if (
        not isinstance(interface["device"], str)
        or interface["device"] != f"/dev/i2c-{interface['bus']}"
    ):
        raise ProfileError("hardware interface device must match its I2C bus")
    try:
        address = int(str(interface["address"]), 0)
    except ValueError as error:
        raise ProfileError("hardware interface address must be an integer") from error
    if not 0x03 <= address <= 0x77:
        raise ProfileError("hardware interface address is outside the usable 7-bit range")
    if type(interface["frequency_hz"]) is not int or interface["frequency_hz"] <= 0:
        raise ProfileError("hardware interface frequency_hz must be positive")
    if (
        isinstance(interface["logic_voltage_v"], bool)
        or not isinstance(interface["logic_voltage_v"], (int, float))
        or interface["logic_voltage_v"] <= 0
    ):
        raise ProfileError("hardware interface logic_voltage_v must be positive")
    pins = interface["pins"]
    if not isinstance(pins, dict) or set(pins) != {"SDA", "SCL"}:
        raise ProfileError("hardware interface pins must define SDA and SCL")
    if not all(isinstance(value, str) and value for value in pins.values()):
        raise ProfileError("hardware interface pin labels must be non-empty strings")
    return binding


def _validate_i2c_csv(path: Path, binding: dict[str, Any]) -> None:
    try:
        with path.open(encoding="utf-8", newline="") as handle:
            rows = [row for row in csv.DictReader(handle) if row.get("driver") == "pca9685"]
    except OSError as error:
        raise ProfileError(f"cannot read runtime I2C configuration: {path}: {error}") from error
    if len(rows) != 1:
        raise ProfileError("runtime I2C configuration must contain exactly one PCA9685 row")
    row = rows[0]
    interface = binding["interfaces"][0]
    try:
        csv_bus = int(row["bus"], 10)
        csv_address = int(row["address"], 0)
        binding_address = int(str(interface["address"]), 0)
    except (KeyError, TypeError, ValueError) as error:
        raise ProfileError("runtime I2C bus/address is invalid") from error
    if (csv_bus, row.get("dev"), csv_address) != (
        interface["bus"],
        interface["device"],
        binding_address,
    ):
        raise ProfileError("runtime I2C configuration drifts from the hardware binding")


def _artifact_manifest(
    path: Path,
    app_id: str,
    target: str,
    install_dir: str,
    entrypoint: str,
) -> None:
    manifest = _load_object(path, "artifact manifest")
    if manifest.get("target") != target:
        raise ProfileError("artifact manifest target does not match the deployment")
    expected_entrypoint = f"{install_dir}/{entrypoint}"
    if manifest.get("entrypoint") != expected_entrypoint:
        raise ProfileError("artifact manifest entrypoint does not match the application")
    try:
        app_files = manifest["deploy"]["app"]["files"]
    except (KeyError, TypeError) as error:
        raise ProfileError("artifact manifest has no deploy.app.files") from error
    expected = {"src": f"files/{app_id}", "dest": install_dir, "mode": "0755"}
    if not isinstance(app_files, list) or expected not in app_files:
        raise ProfileError("artifact manifest does not deploy the selected application capsule")


def compose(deployment_id: str) -> tuple[dict[str, Any], dict[str, Any], dict[str, Path]]:
    deployment_id = _safe_id(deployment_id, "deployment id")
    profile_path = REPOSITORY_ROOT / "config" / "deployments" / f"{deployment_id}.json"
    profile = _load_object(profile_path, "deployment profile")
    _exact_keys(
        profile,
        {
            "schema_version",
            "id",
            "product",
            "application",
            "target",
            "binding",
            "runtime",
            "artifact",
            "target_config",
            "packager",
        },
        "deployment profile",
    )
    if profile["schema_version"] != 1:
        raise ProfileError("deployment profile schema_version must be 1")
    if profile["id"] != deployment_id:
        raise ProfileError("deployment profile id must match its filename")
    product_id = _safe_id(profile["product"], "deployment product")
    target = _safe_id(profile["target"], "deployment target")

    runtime = profile["runtime"]
    artifact = profile["artifact"]
    target_config = profile["target_config"]
    if not isinstance(runtime, dict):
        raise ProfileError("deployment runtime must be an object")
    if not isinstance(artifact, dict):
        raise ProfileError("deployment artifact must be an object")
    if not isinstance(target_config, dict):
        raise ProfileError("deployment target_config must be an object")
    _exact_keys(runtime, {"i2c", "connections", "servo_calibration"}, "deployment runtime")
    _exact_keys(artifact, {"kind", "manifest"}, "deployment artifact")
    _exact_keys(target_config, {"defaults", "local"}, "deployment target_config")
    if artifact["kind"] not in {"uuu-image-and-app", "ssh-app"}:
        raise ProfileError("deployment artifact kind is unsupported")

    paths = {
        "profile": profile_path.resolve(),
        "application": _relative_path(
            REPOSITORY_ROOT, profile["application"], "deployment application"
        ),
        "binding": _relative_path(REPOSITORY_ROOT, profile["binding"], "deployment binding"),
        "i2c": _relative_path(REPOSITORY_ROOT, runtime["i2c"], "deployment runtime.i2c"),
        "connections": _relative_path(
            REPOSITORY_ROOT, runtime["connections"], "deployment runtime.connections"
        ),
        "servo_calibration": _relative_path(
            REPOSITORY_ROOT,
            runtime["servo_calibration"],
            "deployment runtime.servo_calibration",
        ),
        "artifact_manifest": _relative_path(
            REPOSITORY_ROOT, artifact["manifest"], "deployment artifact.manifest"
        ),
        "target_defaults": _relative_path(
            REPOSITORY_ROOT, target_config["defaults"], "deployment target_config.defaults"
        ),
        "target_local": _relative_path(
            REPOSITORY_ROOT,
            target_config["local"],
            "deployment target_config.local",
            must_exist=False,
        ),
        "packager": _relative_path(REPOSITORY_ROOT, profile["packager"], "deployment packager"),
    }
    app = _application_manifest(paths["application"])
    binding = _binding(paths["binding"], product_id, target)
    _validate_i2c_csv(paths["i2c"], binding)
    _artifact_manifest(
        paths["artifact_manifest"],
        app["id"],
        target,
        app["runtime"]["install_dir"],
        app["runtime"]["entrypoint"],
    )
    if not os.access(paths["packager"], os.X_OK):
        raise ProfileError(f"deployment packager is not executable: {paths['packager']}")
    return profile, app, paths


def _relative(path: Path) -> str:
    return path.relative_to(REPOSITORY_ROOT).as_posix()


def _description(
    profile: dict[str, Any],
    app: dict[str, Any],
    paths: dict[str, Path],
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "deployment": profile["id"],
        "product": profile["product"],
        "application": app["id"],
        "target": profile["target"],
        "artifact_kind": profile["artifact"]["kind"],
        "application_runtime": {
            "install_dir": app["runtime"]["install_dir"],
            "entrypoint": app["runtime"]["entrypoint"],
            "configuration": app["runtime"]["configuration"],
        },
        "paths": {name: _relative(path) for name, path in paths.items()},
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--deployment",
        default=os.environ.get("GAR_DEPLOYMENT") or os.environ.get("GAR_TARGET") or "frdm-imx91s",
    )
    parser.add_argument("--describe", action="store_true")
    parser.add_argument("action", nargs="?", choices=("clean",))
    arguments = parser.parse_args(argv)
    if arguments.describe and arguments.action:
        parser.error("--describe cannot be combined with clean")

    try:
        profile, app, paths = compose(arguments.deployment)
    except ProfileError as error:
        print(f"deployment profile: {error}", file=sys.stderr)
        return 2

    requested_target = os.environ.get("GAR_TARGET")
    if requested_target and requested_target != profile["target"]:
        print(
            "deployment profile: GAR_TARGET does not match the selected deployment: "
            f"{requested_target} != {profile['target']}",
            file=sys.stderr,
        )
        return 2
    if arguments.describe:
        print(json.dumps(_description(profile, app, paths), ensure_ascii=False, indent=2))
        return 0

    app_root = paths["application"].parent
    environment = dict(os.environ)
    environment.update(
        {
            "GAR_DEPLOYMENT": profile["id"],
            "GAR_DEPLOYMENT_PROFILE": str(paths["profile"]),
            "GAR_PRODUCT_ID": profile["product"],
            "GAR_TARGET": profile["target"],
            "GAR_APP_ID": app["id"],
            "GAR_APP_MANIFEST": str(paths["application"]),
            "GAR_APP_ROOT": str(app_root),
            "GAR_APP_BUILD_GOAL": app["build"]["goal"],
            "GAR_APP_BINARY": str((app_root / app["build"]["binary"]).resolve(strict=False)),
            "GAR_APP_BINARY_NAME": app["build"]["artifact_name"],
            "GAR_APP_ENTRYPOINT": str((app_root / app["runtime"]["entrypoint"]).resolve()),
            "GAR_APP_ENTRYPOINT_NAME": app["runtime"]["entrypoint"],
            "GAR_APP_README": str((app_root / app["runtime"]["readme"]).resolve()),
            "GAR_APP_INSTALL_DIR": app["runtime"]["install_dir"],
            "GAR_APP_I2C_CONFIG_DEST": app["runtime"]["configuration"]["i2c"],
            "GAR_APP_CONNECTIONS_CONFIG_DEST": app["runtime"]["configuration"][
                "connections"
            ],
            "GAR_APP_SERVO_CONFIG_DEST": app["runtime"]["configuration"][
                "servo_calibration"
            ],
            "GAR_HARDWARE_BINDING": str(paths["binding"]),
            "GAR_RUNTIME_I2C_CONFIG": str(paths["i2c"]),
            "GAR_RUNTIME_CONNECTIONS_CONFIG": str(paths["connections"]),
            "GAR_RUNTIME_SERVO_CONFIG": str(paths["servo_calibration"]),
            "GAR_TARGET_ARTIFACT_KIND": profile["artifact"]["kind"],
            "GAR_TARGET_ARTIFACT_MANIFEST": str(paths["artifact_manifest"]),
            "GAR_TARGET_DEFAULT_CONFIG": str(paths["target_defaults"]),
            "GAR_TARGET_LOCAL_CONFIG": str(paths["target_local"]),
        }
    )
    command = [str(paths["packager"])]
    if arguments.action:
        command.append(arguments.action)
    os.execve(command[0], command, environment)
    return 127


if __name__ == "__main__":
    raise SystemExit(main())
