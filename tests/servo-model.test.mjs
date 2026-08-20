import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  channelPulse,
  emptyPca9685State,
  normalisePca9685State,
  pulseToPreviewAngle,
} from "../panel/components/servo-model.mjs";

test("an empty PCA9685 state has sixteen stopped channels", () => {
  const state = emptyPca9685State();
  assert.equal(state.channels.length, 16);
  assert.equal(state.channels.every((channel) => channel.fullOff), true);
});

test("a 307-count pulse at 50 Hz is approximately 1.5 ms", () => {
  const pulse = channelPulse(
    { on: 0, off: 307, fullOn: false, fullOff: false },
    50,
  );
  assert.equal(pulse.active, true);
  assert.equal(pulse.counts, 307);
  assert.ok(Math.abs(pulse.pulseUs - 1499.0) < 1);
  assert.ok(Math.abs(pulseToPreviewAngle(pulse.pulseUs) - 90) < 1);
});

test("untrusted bridge values are bounded before rendering", () => {
  const state = normalisePca9685State({
    address: 999,
    frequencyHz: 50,
    channels: [{ on: -12, off: 9000, fullOn: false, fullOff: false }],
  });
  assert.equal(state.address, 0x7f);
  assert.equal(state.channels[0].on, 0);
  assert.equal(state.channels[0].off, 4095);
  assert.equal(state.channels.length, 16);
});

test("the panel declares four individually identified SG90 elements", async () => {
  const panelUrl = new URL("../panel/index.html", import.meta.url);
  const html = await readFile(panelUrl, "utf8");
  const openings = [...html.matchAll(/<gar-sg90\s+([^>]+)>/g)];
  const closings = [...html.matchAll(/<\/gar-sg90>/g)];
  assert.equal(openings.length, 4);
  assert.equal(closings.length, 4);
  assert.deepEqual(
    openings.map(([, attributes]) => attributes.match(/id="([^"]+)"/)?.[1]),
    ["sg90-1", "sg90-2", "sg90-3", "sg90-4"],
  );
  assert.deepEqual(
    openings.map(([, attributes]) => attributes.match(/channel="([^"]+)"/)?.[1]),
    ["0", "1", "2", "3"],
  );
  assert.equal(html.includes("gar-sg90-four-pack"), false);
});
