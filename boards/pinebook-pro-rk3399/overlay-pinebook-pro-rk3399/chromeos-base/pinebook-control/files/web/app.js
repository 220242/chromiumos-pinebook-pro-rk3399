// Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
// Distributed under the terms of the GNU General Public License v2
//
// The Pinebook app: live hardware state from /api/status, settings through
// /api/settings, and an always-on-top overlay (Document Picture-in-Picture).

"use strict";

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"]/g,
  (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

const mhz = (khz) => (khz ? Math.round(khz / 1000) + " МГц" : "—");
const ghzHz = (hz) => (hz ? Math.round(hz / 1e6) + " МГц" : "—");

const PROFILE_NAMES = {
  powersave: "Экономия",
  balanced: "Сбалансированный",
  performance: "Производительность",
  custom: "Свой",
};

let info = null;       // /api/settings
let last = null;       // /api/status
let pipWindow = null;  // overlay

async function api(path, body) {
  const opts = body === undefined ? {} : {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Pinebook": "1" },
    body: JSON.stringify(body),
  };
  const r = await fetch(path, opts);
  if (!r.ok) throw new Error(path + ": " + r.status);
  return r.json();
}

function toast(text) {
  const t = $("toast");
  t.textContent = text;
  t.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (t.hidden = true), 5000);
}

function bar(value, max, cls = "") {
  const p = max ? Math.max(0, Math.min(100, (100 * value) / max)) : 0;
  return `<div class="bar ${cls}"><div style="width:${p}%"></div></div>`;
}

function tempClass(t) {
  return t >= 80 ? "hot" : t >= 65 ? "warm" : "";
}

// --- Monitor ---------------------------------------------------------------

function renderStatus(s) {
  $("cpu-load").textContent = s.cpu_load != null ? Math.round(s.cpu_load) + "%" : "";
  $("cpu").innerHTML = s.cpu.map((c) => `
    <div class="row"><b>${c.name}</b><span>${mhz(c.cur_khz)}
      <small>из ${mhz(c.max_khz)} · ${esc(c.governor)}</small></span></div>
    ${bar(c.cur_khz, c.hw_max_khz)}
    <div class="cores">${c.load.map((l, i) =>
      `<span title="cpu${c.cpus[i]}">${l == null ? "—" : Math.round(l) + "%"}</span>`).join("")}</div>
  `).join("");

  const g = s.gpu || {};
  $("gpu").innerHTML = g.cur_hz ? `
    <div class="row"><b>Частота</b><span>${ghzHz(g.cur_hz)}
      <small>из ${ghzHz(g.max_hz)} · ${esc(g.governor)}</small></span></div>
    ${bar(g.cur_hz, 800e6)}` : "<p class=hint>Нет данных devfreq</p>";

  $("temps").innerHTML = Object.entries(s.temps).map(([k, t]) => `
    <div class="row"><b>${esc(k.replace("-thermal", "").toUpperCase())}</b>
      <span class="${tempClass(t)}">${t.toFixed(1)} °C</span></div>
    ${bar(t, 95, tempClass(t))}`).join("");

  const b = s.battery;
  const st = { Charging: "заряжается", Discharging: "от батареи", Full: "заряжен",
               "Not charging": "не заряжается" }[b.status] || b.status || "";
  $("power").innerHTML = `
    <div class="row"><b>Батарея</b><span>${b.capacity ?? "—"}% <small>${esc(st)}</small></span></div>
    ${bar(b.capacity || 0, 100)}
    <div class="row"><b>Напряжение</b><span>${b.voltage_v ? b.voltage_v.toFixed(2) + " В" : "—"}</span></div>
    <div class="row"><b>Потребление</b><span>${b.est_watts != null ? "≈ " + b.est_watts.toFixed(1) + " Вт" :
      `<small>${b.status === "Discharging" ? "оценка появится через несколько минут" : "только от батареи"}</small>`}</span></div>
    ${b.time_to_empty_min ? `<div class="row"><b>Осталось</b><span>${Math.floor(b.time_to_empty_min / 60)} ч ${b.time_to_empty_min % 60} мин</span></div>` : ""}
    <div class="row"><b>Зарядка</b><span>${b.ac ? "блок питания" : ""}${b.usb_c ? (b.ac ? ", " : "") +
      `USB-C ${b.usb_c.volts} В / ${b.usb_c.max_amps} А` : ""}${!b.ac && !b.usb_c ? "нет" : ""}</span></div>
    <p class="hint">Датчик батареи не измеряет ток, мощность оценивается по разряду.</p>`;

  const a = s.accel;
  const dec = a.video.filter((v) => /dec/i.test(v.name));
  $("accel").innerHTML = `
    <div class="row"><b>GPU (Panfrost)</b><span class="${a.gpu_users.length ? "ok" : ""}">
      ${a.gpu_users.length ? "используется" : "не используется"}</span></div>
    <p class="hint">${esc(a.gpu_users.join(", "))}</p>
    <div class="row"><b>Видеодекодер</b><span class="${dec.length ? "ok" : ""}">
      ${dec.length ? "работает" : "простаивает"}</span></div>
    ${a.video.map((v) => `<p class="hint">${esc(v.name)}: ${esc(v.users.join(", "))}</p>`).join("")}
    <p class="hint">Устройства: ${esc(a.video_devices.join(", ") || "нет")}.
      Включи видео: при аппаратном декодировании здесь появится rkvdec или hantro.</p>`;

  const m = s.memory;
  $("memory").innerHTML = `
    <div class="row"><b>ОЗУ</b><span>${m.total_mb - m.available_mb} / ${m.total_mb} МБ</span></div>
    ${bar(m.total_mb - m.available_mb, m.total_mb)}
    <div class="row"><b>zram</b><span>${m.swap_used_mb} / ${m.swap_total_mb} МБ</span></div>
    <div class="row"><b>Буферы графики</b><span>${m.gpu_buffers_mb} МБ</span></div>`;

  if (pipWindow) renderOverlay(s);
}

// --- Overlay -----------------------------------------------------------------

function overlayHtml(s) {
  const c = s.cpu.map((x) => `${x.name.replace("Cortex-", "")} ${mhz(x.cur_khz)}`).join(" · ");
  const t = Object.entries(s.temps).map(([k, v]) =>
    `<span class="${tempClass(v)}">${esc(k.replace("-thermal", "").toUpperCase())} ${Math.round(v)}°</span>`).join(" ");
  const dec = s.accel.video.filter((v) => /dec/i.test(v.name)).length;
  const b = s.battery;
  return `
    <div>${c}</div>
    <div>GPU ${ghzHz(s.gpu.cur_hz)} · CPU ${Math.round(s.cpu_load || 0)}%</div>
    <div>${t}</div>
    <div>${b.capacity ?? "—"}%${b.est_watts != null ? " · ≈" + b.est_watts.toFixed(1) + " Вт" : ""}
      · ${s.accel.gpu_users.length ? "GPU✓" : "GPU–"} · ${dec ? "HW-видео✓" : "HW-видео–"}</div>`;
}

function renderOverlay(s) {
  const el = pipWindow.document.getElementById("o");
  if (el) el.innerHTML = overlayHtml(s);
}

async function openOverlay() {
  if (pipWindow) { pipWindow.close(); return; }
  const css = `body{margin:0;padding:6px 10px;font:13px/1.45 system-ui,sans-serif;
    background:#111;color:#eee}.hot{color:#ff6b6b}.warm{color:#ffb84d}`;
  if ("documentPictureInPicture" in window) {
    pipWindow = await documentPictureInPicture.requestWindow({ width: 300, height: 110 });
    pipWindow.document.head.innerHTML = `<style>${css}</style>`;
    pipWindow.document.body.innerHTML = '<div id="o"></div>';
    pipWindow.addEventListener("pagehide", () => (pipWindow = null));
  } else {
    pipWindow = window.open("", "pinebook-overlay", "width=320,height=130");
    pipWindow.document.write(`<style>${css}</style><div id="o"></div>`);
    pipWindow.addEventListener("beforeunload", () => (pipWindow = null));
  }
  if (last) renderOverlay(last);
}

// --- Settings ----------------------------------------------------------------

function fillSelect(id, values, label, selected, auto) {
  const opts = (auto ? [`<option value="">${auto}</option>`] : []).concat(
    values.map((v) => `<option value="${v}">${esc(label(v))}</option>`));
  $(id).innerHTML = opts.join("");
  $(id).value = selected == null ? "" : String(selected);
}

function renderSettings() {
  const s = info.settings;
  $("profiles").innerHTML = info.profiles.map((p) =>
    `<button data-profile="${p}" class="${p === s.profile ? "active" : ""}">${PROFILE_NAMES[p]}</button>`).join("");
  $("custom").hidden = s.profile !== "custom";
  const c = s.custom;
  fillSelect("little_max", info.little_freqs, mhz, c.little_max, "Максимальная");
  fillSelect("big_max", info.big_freqs, mhz, c.big_max, "Максимальная");
  fillSelect("gpu_max", info.gpu_freqs, ghzHz, c.gpu_max, "Максимальная");
  fillSelect("cpu_governor", info.cpu_governors, (x) => x, c.cpu_governor);
  fillSelect("gpu_governor", info.gpu_governors, (x) => x, c.gpu_governor);
  const a = info.applied;
  $("applied").textContent = `Сейчас: A53 до ${mhz(a.little_max)}, A72 до ${mhz(a.big_max)}, ` +
    `${a.cpu_governor}; GPU до ${ghzHz(a.gpu_max)}, ${a.gpu_governor}.`;

  $("boot-logs").checked = info.boot_logs !== false;
  $("boot-logs").disabled = info.boot_logs == null;

  const t = s.tune;
  $("overclock").value = t.overclock;
  const uv = (v) => (v ? "−" + v + " мВ" : "Нет");
  fillSelect("cpu_undervolt_mv", info.undervolt_steps, uv, t.cpu_undervolt_mv);
  fillSelect("gpu_undervolt_mv", info.undervolt_steps, uv, t.gpu_undervolt_mv);
  const f = info.tune_file;
  $("tune-state").textContent = f == null ? "Сейчас заводские частоты и напряжения." :
    f.unknown ? "На EFI-SYSTEM есть pinebook-tune.scr неизвестного формата." :
    `На EFI-SYSTEM сохранено: разгон ${f.overclock}, CPU −${f.cpu_undervolt_mv} мВ, ` +
    `GPU −${f.gpu_undervolt_mv} мВ (работает после перезагрузки).`;

  const names = { little: "Cortex-A53", big: "Cortex-A72", gpu: "GPU" };
  $("tables").innerHTML = Object.keys(names).map((k) => `
    <h3>${names[k]}</h3>
    <table><tr><th>Сейчас</th><th>После перезагрузки</th></tr>
    ${Array.from({ length: Math.max(info.running_tables[k].length, info.tune_tables[k].length) },
      (_, i) => {
        const r = info.running_tables[k][i], n = info.tune_tables[k][i];
        return `<tr><td>${r ? `${r[0]} МГц, ${r[1]} мВ` : ""}</td><td>${n ? `${n[0]} МГц, ${n[1]} мВ` : ""}</td></tr>`;
      }).join("")}</table>`).join("");
}

async function loadSettings() {
  info = await api("/api/settings");
  renderSettings();
}

async function save(body, done) {
  try {
    const r = await api("/api/settings", body);
    if (r.error) toast(r.error);
    else if (done) toast(done(r));
    await loadSettings();
  } catch (e) {
    toast("Ошибка: " + e.message);
  }
}

function customBody() {
  const v = (id) => $(id).value;
  return {
    profile: "custom",
    custom: {
      little_max: v("little_max") || null, big_max: v("big_max") || null,
      gpu_max: v("gpu_max") || null,
      cpu_governor: v("cpu_governor"), gpu_governor: v("gpu_governor"),
    },
  };
}

// --- Wiring --------------------------------------------------------------------

document.querySelectorAll(".tab").forEach((b) => b.addEventListener("click", () => {
  document.querySelectorAll(".tab").forEach((x) => x.classList.toggle("active", x === b));
  document.querySelectorAll(".page").forEach((p) => (p.hidden = p.id !== b.dataset.tab));
  if (b.dataset.tab === "settings") loadSettings().catch((e) => toast(e.message));
}));

$("profiles").addEventListener("click", (e) => {
  const p = e.target.dataset.profile;
  if (!p) return;
  save(p === "custom" ? customBody() : { profile: p },
    () => "Режим: " + PROFILE_NAMES[p]);
});

["little_max", "big_max", "gpu_max", "cpu_governor", "gpu_governor"].forEach((id) =>
  $(id).addEventListener("change", () => save(customBody(), () => "Применено")));

$("boot-logs").addEventListener("change", (e) =>
  save({ boot_logs: e.target.checked },
    () => e.target.checked ? "Логи загрузки включены" : "Логи загрузки выключены"));

$("tune-apply").addEventListener("click", () => {
  const tune = {
    overclock: $("overclock").value,
    cpu_undervolt_mv: +$("cpu_undervolt_mv").value,
    gpu_undervolt_mv: +$("gpu_undervolt_mv").value,
  };
  if (tune.overclock !== "off" &&
      !confirm("Разгон повышает напряжение и нагрев. Если система станет нестабильной, " +
               "удали pinebook-tune.scr с EFI-SYSTEM. Продолжить?")) return;
  save({ tune }, (r) => r.reboot_needed ? "Сохранено. Перезагрузи ноутбук, чтобы применить."
                                        : "Без изменений.");
});

$("overlay").addEventListener("click", () => openOverlay().catch((e) => toast(e.message)));

async function poll() {
  try {
    last = await api("/api/status");
    renderStatus(last);
  } catch (e) {
    $("cpu").innerHTML = `<p class="hint">Служба pinebook-control не отвечает (${esc(e.message)})</p>`;
  }
  setTimeout(poll, 1000);
}
poll();
