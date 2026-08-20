import { bridgeClient } from "/components/bridge-client.js";
import {
  channelPulse,
  emptyPca9685State,
  pca9685StateFromMessage,
  pulseToPreviewAngle,
} from "./servo-model.mjs";

function integerAttribute(element, name, fallback) {
  const value = Number.parseInt(element.getAttribute(name) ?? "", 10);
  return Number.isInteger(value) ? value : fallback;
}

class GarSg90 extends HTMLElement {
  #state = emptyPca9685State();
  #messageHandler = ({ detail }) => this.update(detail);

  connectedCallback() {
    const componentId = this.id.trim();
    const controllerId = (this.getAttribute("controller") ?? "").trim();
    const channel = integerAttribute(this, "channel", -1);
    const controller = document.getElementById(controllerId);
    const valid = componentId
      && controller?.matches("gar-pca9685")
      && channel >= 0
      && channel <= 15;

    this.innerHTML = `
      <article class="hardware-card servo-card" aria-label="SG90 servo motor">
        <header class="component-heading">
          <div><span class="eyebrow">MICRO SERVO</span><h2>SG90</h2></div>
          <output data-state>${valid ? "waiting" : "configuration error"}</output>
        </header>
        <div class="servo-drawing" aria-hidden="true">
          <span class="servo-ear left"></span><span class="servo-ear right"></span>
          <span class="servo-body"><i class="servo-horn"></i></span>
          <span class="servo-wire signal"></span><span class="servo-wire power"></span><span class="servo-wire ground"></span>
        </div>
        <div class="servo-reading">
          <strong data-component-id></strong><span data-route></span>
          <output data-angle>—</output><small data-pulse>signal off</small>
        </div>
      </article>`;

    this.querySelector("[data-component-id]").textContent = componentId || "missing id";
    this.querySelector("[data-route]").textContent = controllerId && channel >= 0
      ? `${controllerId} · CH${channel}`
      : "controller/channel required";
    this.toggleAttribute("data-invalid", !valid);

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
    if (!this.isConnected || this.hasAttribute("data-invalid")) return;
    const channelIndex = integerAttribute(this, "channel", -1);
    const channel = this.#state.channels[channelIndex];
    const pulse = channelPulse(channel, this.#state.frequencyHz);
    const minimum = integerAttribute(this, "min-pulse-us", 500);
    const maximum = integerAttribute(this, "max-pulse-us", 2500);
    const angle = pulseToPreviewAngle(pulse.pulseUs, minimum, maximum);

    this.classList.toggle("active", pulse.active);
    this.querySelector("[data-state]").textContent = pulse.active ? "active" : "stopped";
    this.querySelector(".servo-horn").style.transform = `rotate(${angle - 90}deg)`;
    this.querySelector("[data-angle]").textContent = pulse.active ? `${Math.round(angle)}°` : "—";
    this.querySelector("[data-pulse]").textContent = pulse.active
      ? `${Math.round(pulse.pulseUs)} µs`
      : "signal off";
  }
}

customElements.define("gar-sg90", GarSg90);
