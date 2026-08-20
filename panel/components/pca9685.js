import { bridgeClient } from "/components/bridge-client.js";
import {
  channelPulse,
  emptyPca9685State,
  pca9685StateFromMessage,
} from "./servo-model.mjs";

class GarPca9685 extends HTMLElement {
  #state = emptyPca9685State();
  #messageHandler = ({ detail }) => this.update(detail);

  connectedCallback() {
    this.innerHTML = `
      <section class="hardware-card pca-board" aria-label="PCA9685 servo controller">
        <header class="component-heading">
          <div><span class="eyebrow">PWM CONTROLLER · 1 BOARD</span><h2>PCA9685</h2></div>
          <output data-address>0x40</output>
        </header>
        <div class="board-visual" aria-hidden="true">
          <span class="terminal terminal-power">V+</span>
          <span class="chip">PCA<br>9685</span>
          <span class="terminal terminal-i2c">I²C</span>
          <div class="channel-pins"></div>
        </div>
        <div class="component-stats">
          <span>Device <output data-device></output></span>
          <span>Frequency <output data-frequency>waiting</output></span>
          <span>Active <output data-active>0 / 16</output></span>
        </div>
        <ol class="channel-list" aria-label="PWM channel states"></ol>
      </section>`;

    const pins = this.querySelector(".channel-pins");
    const list = this.querySelector(".channel-list");
    for (let channel = 0; channel < 16; channel += 1) {
      const pin = document.createElement("i");
      pin.dataset.channel = String(channel);
      pins.append(pin);

      const item = document.createElement("li");
      item.innerHTML = `<span>CH${channel}</span><meter min="0" max="4096" value="0"></meter><output>off</output>`;
      list.append(item);
    }

    this.querySelector("[data-device]").textContent = this.getAttribute("device") || "unbound";

    bridgeClient.addEventListener("message", this.#messageHandler);
    if (bridgeClient.state) this.update({ type: "init", state: bridgeClient.state });
    else this.render();
  }

  disconnectedCallback() {
    bridgeClient.removeEventListener("message", this.#messageHandler);
  }

  update(message) {
    this.#state = pca9685StateFromMessage(message, this.#state);
    this.render();
  }

  render() {
    if (!this.isConnected) return;
    const frequency = this.#state.frequencyHz;
    this.querySelector("[data-address]").textContent = `0x${this.#state.address.toString(16).padStart(2, "0").toUpperCase()}`;
    this.querySelector("[data-frequency]").textContent = frequency ? `${frequency.toFixed(1)} Hz` : "waiting";

    let activeCount = 0;
    this.#state.channels.forEach((channel, index) => {
      const pulse = channelPulse(channel, frequency);
      if (pulse.active) activeCount += 1;
      const pin = this.querySelector(`.channel-pins [data-channel="${index}"]`);
      pin.classList.toggle("active", pulse.active);
      const row = this.querySelector(`.channel-list li:nth-child(${index + 1})`);
      row.classList.toggle("active", pulse.active);
      row.querySelector("meter").value = pulse.counts;
      row.querySelector("output").textContent = pulse.active ? `${Math.round(pulse.pulseUs)} µs` : "off";
    });
    this.querySelector("[data-active]").textContent = `${activeCount} / 16`;
  }
}

customElements.define("gar-pca9685", GarPca9685);
