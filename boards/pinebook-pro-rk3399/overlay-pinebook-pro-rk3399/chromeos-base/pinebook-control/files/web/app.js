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

  const k = info.google_keys || {};
  $("keys-state").textContent =
    (k.active ? "Chrome сейчас запущен с ключами. " : "Chrome сейчас без ключей. ") +
    (k.saved ? `Сохранены ключи для ${k.client_id}.` : "Ключи в приложении не сохранены.");

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
  loadMigrate();
}

// --- Moving the system -------------------------------------------------------

async function loadMigrate() {
  let m;
  try { m = await api("/api/migrate"); } catch (e) { return; }
  const ts = Array.isArray(m.targets) ? m.targets : [];
  $("migrate-targets").innerHTML = ts.length ? ts.map((t, i) => `
    <label class="row"><span>${t.kind === "nvme" ? "NVMe SSD" : "eMMC"} ${esc(t.model || "")},
      ${t.size_gb} ГБ <small>${t.partitions ? `(сейчас ${t.partitions} разд., будут стёрты)` : ""}</small></span>
      <input type="radio" name="migrate-target" value="${esc(t.device)}" ${i === 0 ? "checked" : ""}></label>`).join("")
    : "<p class=hint>Нет дисков для переноса: eMMC не найдена, NVMe не установлен.</p>";
  $("migrate-go").disabled = !ts.length;
  $("migrate-state").textContent =
    m.error ? "Ошибка: " + m.error :
    m.scheduled ? `Перенос на ${m.scheduled} начнётся при следующей загрузке.` :
    (m.markers || []).length ? `Система уже перенесена (${m.markers.join(", ")} на этой карте).` :
    `Система загружена с ${m.booted_from || "?"}.` + (m.power_ok ? "" : " Подключи зарядку перед переносом.");
  $("migrate-log").textContent = m.log || "Ещё не запускался.";
}

async function postMigrate(body, done) {
  try {
    const r = await fetch("/api/migrate", {
      method: "POST", headers: { "Content-Type": "application/json", "X-Pinebook": "1" },
      body: JSON.stringify(body),
    }).then((x) => x.json());
    toast(r.error ? "Ошибка: " + r.error : done);
  } catch (e) {
    toast("Ошибка: " + e.message);
  }
  loadMigrate();
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

// --- Power ---------------------------------------------------------------------

const LED_NAMES = { "green:power": "Зелёный индикатор", "red:standby": "Красный индикатор" };
const LED_MODES = {
  on: "Горит", off: "Не горит", heartbeat: "Пульс", timer: "Мигает", cpu: "Загрузка CPU",
  mmc1: "Активность microSD", mmc2: "Активность eMMC", phy0tx: "Передача Wi-Fi",
  "default-on": "Горит (по умолчанию)", panic: "Только при сбое ядра",
};
const SLEEP_NAMES = {
  s2idle: "Лёгкий (s2idle): быстро просыпается, разряжает батарею быстрее",
  deep: "Глубокий (deep): экономнее, экспериментально",
  shallow: "Неглубокий (shallow)",
};

let power = null;
let history = [];

const kv = (rows) => `<dl class="kv">${rows.filter((r) => r && r[1] != null && r[1] !== "")
  .map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join("")}</dl>`;
const num = (v) => (v == null || v === "" ? null : Number(v));

function renderPower() {
  const sup = power.supplies || {};
  const b = sup["cw2015-battery"] || {};
  const st = { Charging: "заряжается", Discharging: "от батареи", Full: "заряжен",
               "Not charging": "не заряжается" }[b.status] || b.status;
  const w = last && last.battery && last.battery.est_watts;
  $("battery").innerHTML = kv([
    ["Заряд", b.capacity != null ? `${b.capacity}% (${st})` : null],
    ["Напряжение", num(b.voltage_now) ? (num(b.voltage_now) / 1e6).toFixed(3) + " В" : null],
    ["Запас", num(b.charge_now) ? `${Math.round(num(b.charge_now) / 1000)} из ${Math.round(num(b.charge_full) / 1000)} мА·ч` : null],
    ["Ёмкость по паспорту", num(b.charge_full_design) ? Math.round(num(b.charge_full_design) / 1000) + " мА·ч" : null],
    ["Диапазон напряжений", num(b.voltage_min_design) ? `${(num(b.voltage_min_design) / 1e6).toFixed(2)}–${(num(b.voltage_max_design) / 1e6).toFixed(2)} В` : null],
    ["Осталось", num(b.time_to_empty_now) ? `${Math.floor(num(b.time_to_empty_now) / 3600)} ч ${Math.round(num(b.time_to_empty_now) % 3600 / 60)} мин` : null],
    ["Потребление", w != null ? `≈ ${w.toFixed(1)} Вт` : "оценивается только от батареи"],
    ["Тип", b.technology],
  ]) + `<p class="hint">Датчик CW2015 не измеряет ток: расход оценивается по скорости разряда.</p>`;

  const dc = sup["dc-charger"] || {};
  const tcpm = Object.entries(sup).find(([k]) => k.startsWith("tcpm-source"));
  const t = tcpm ? tcpm[1] : {};
  const u = power.usb_c;
  $("charger").innerHTML = kv([
    ["Разъём питания (DC)", dc.online === "1" ? "подключён" : "не подключён"],
    ["USB-C", u ? (u.partner ? "подключено устройство" : "пусто") : "нет данных"],
    ["Роль USB-C", u && u.partner ? `питание: ${u.power_role === "sink" ? "заряжается от него" : "питает его"}, данные: ${u.data_role}` : null],
    ["Режим", u && u.partner ? u.power_operation_mode : null],
    ["Договорено", t.online === "1" ? `${(num(t.voltage_now) / 1e6).toFixed(1)} В, до ${(num(t.current_max) / 1e6).toFixed(1)} А (${t.usb_type || ""})` : null],
  ]) + (u && u.pdos.length ? `<h3>Что предлагает зарядка (PD)</h3>` + kv(u.pdos.map((p) => [
    p.type.replace("_", " "),
    p.min_mv ? `${p.min_mv / 1000}–${p.mv / 1000} В, ${p.ma / 1000} А` : `${p.mv / 1000} В × ${p.ma / 1000} А = ${(p.mv * p.ma / 1e6).toFixed(0)} Вт`,
  ])) : "");

  const s = power.settings || {};
  const leds = power.leds.map((l) => {
    const modes = ["on", "off", ...l.triggers.filter((x) => x !== "none" && LED_MODES[x])];
    const cur = s.leds && s.leds[l.name] ? s.leds[l.name] :
      (l.trigger === "none" ? (l.brightness ? "on" : "off") : l.trigger);
    return `<label>${esc(LED_NAMES[l.name] || l.name)}
      <select data-led="${esc(l.name)}">${[...new Set([...modes, cur])].map((m) =>
        `<option value="${esc(m)}" ${m === cur ? "selected" : ""}>${esc(LED_MODES[m] || m)}</option>`).join("")}</select></label>`;
  }).join("");
  const cpus = Object.entries(power.cpus_online || {}).map(([n, on]) =>
    `<label><span>Ядро ${n} (${Number(n) >= 4 ? "A72" : "A53"})</span>
      <input type="checkbox" data-cpu="${n}" ${on ? "checked" : ""}></label>`).join("");
  const ps = power.wifi_power_save;
  $("power-controls").innerHTML = leds +
    `<label><span>Энергосбережение Wi-Fi<br><small class="hint">меньше расход, чуть выше задержки</small></span>
      <input type="checkbox" id="wifi-ps" ${ps ? "checked" : ""} ${ps == null ? "disabled" : ""}></label>` +
    `<h3>Ядра процессора</h3>${cpus}
     <div><button id="cpus-little">Только A53 (экономия)</button> <button id="cpus-all">Все ядра</button></div>`;

  const ms = power.mem_sleep;
  const sus = power.suspend || {};
  $("sleep").innerHTML = (ms ? ms.options.map((o) =>
    `<label class="row"><span>${esc(SLEEP_NAMES[o] || o)}</span>
      <input type="radio" name="mem_sleep" value="${esc(o)}" ${o === ms.current ? "checked" : ""}></label>`).join("") : "") +
    kv([["Успешных засыпаний", sus.success], ["Неудачных", sus.fail],
        ["Последняя ошибка", sus.fail && sus.fail !== "0" ? `${sus.last_failed_dev || ""} ${sus.last_failed_step || ""} ${sus.last_failed_errno || ""}` : null]]);

  $("rails").innerHTML = `<div class="rails">${power.regulators.map((r) =>
    `<div class="${r.use ? "" : "off"}"><b>${esc(r.name)}</b> ${r.mv != null ? (r.mv / 1000).toFixed(3) + " В" : ""}
      ${r.use ? "" : "(выключена)"}<br><small>${esc(r.consumers.join(", "))}</small></div>`).join("") ||
    "<p class=hint>Нет данных (debugfs недоступен)</p>"}</div>`;

  wirePowerControls();
}

function wirePowerControls() {
  document.querySelectorAll("[data-led]").forEach((el) => el.addEventListener("change", () =>
    savePower({ leds: { [el.dataset.led]: el.value } })));
  document.querySelectorAll("[data-cpu]").forEach((el) => el.addEventListener("change", () =>
    savePower({ cpus_online: { [el.dataset.cpu]: el.checked } })));
  const ps = $("wifi-ps");
  if (ps) ps.addEventListener("change", () => savePower({ wifi_power_save: ps.checked }));
  const cpusOf = (big) => Object.fromEntries(Object.keys(power.cpus_online).map((n) =>
    [n, big ? true : Number(n) < 4]));
  $("cpus-little").addEventListener("click", () => savePower({ cpus_online: cpusOf(false) }));
  $("cpus-all").addEventListener("click", () => savePower({ cpus_online: cpusOf(true) }));
  document.querySelectorAll("input[name=mem_sleep]").forEach((el) =>
    el.addEventListener("change", () => savePower({ mem_sleep: el.value })));
}

async function savePower(p) {
  try {
    const r = await api("/api/settings", { power: p });
    if (r.error) toast(r.error); else toast("Применено");
  } catch (e) {
    toast("Ошибка: " + e.message);
  }
  loadPower();
}

async function loadPower() {
  try {
    [power, history] = await Promise.all([api("/api/power"), api("/api/history")]);
    renderPower();
    drawChart();
  } catch (e) {
    toast(e.message);
  }
}

function drawChart() {
  const c = $("chart");
  const dpr = window.devicePixelRatio || 1;
  const wpx = c.clientWidth, hpx = c.clientHeight || 160;
  c.width = wpx * dpr; c.height = hpx * dpr;
  const g = c.getContext("2d");
  g.scale(dpr, dpr);
  g.clearRect(0, 0, wpx, hpx);
  const css = getComputedStyle(document.documentElement);
  g.strokeStyle = css.getPropertyValue("--bar"); g.lineWidth = 1;
  for (let i = 0; i <= 4; i++) { const y = 4 + (hpx - 8) * i / 4; g.beginPath(); g.moveTo(0, y); g.lineTo(wpx, y); g.stroke(); }
  if (history.length < 2) {
    $("chart-legend").textContent = "История копится: точка каждые 10 секунд после запуска службы.";
    return;
  }
  const t0 = history[0].t, t1 = history[history.length - 1].t;
  const maxW = Math.max(10, ...history.map((p) => p.w || 0));
  const series = [
    ["bat", 0, 100, css.getPropertyValue("--accent"), "Заряд, %"],
    ["cpu_c", 20, 100, css.getPropertyValue("--warm"), "CPU, °C (20–100)"],
    ["load", 0, 100, css.getPropertyValue("--muted"), "Загрузка CPU, %"],
    ["w", 0, maxW, css.getPropertyValue("--ok"), `Потребление, Вт (0–${maxW.toFixed(0)})`],
  ];
  for (const [key, lo, hi, color] of series) {
    g.strokeStyle = color.trim(); g.lineWidth = 1.5; g.beginPath();
    let started = false;
    for (const p of history) {
      if (p[key] == null) { started = false; continue; }
      const x = (p.t - t0) / Math.max(1, t1 - t0) * wpx;
      const y = 4 + (hpx - 8) * (1 - Math.min(1, Math.max(0, (p[key] - lo) / (hi - lo))));
      if (started) g.lineTo(x, y); else { g.moveTo(x, y); started = true; }
    }
    g.stroke();
  }
  const mins = Math.round((t1 - t0) / 60);
  $("chart-legend").innerHTML = series.map(([, , , color, name]) =>
    `<span style="color:${color.trim()}">■</span> ${esc(name)}`).join(" &nbsp; ") + ` · последние ${mins} мин`;
}

// --- Hardware ------------------------------------------------------------------

async function loadHardware() {
  let h;
  try { h = await api("/api/hardware"); } catch (e) { toast(e.message); return; }
  const card = (title, body) => `<div class="card"><h2>${esc(title)}</h2>${body}</div>`;
  const up = h.uptime_s;
  const sd = h.storage.map((s) => {
    const slow = s.type === "SD" && s.timing && !/uhs|sdr|ddr/i.test(s.timing);
    return kv([
      [s.type === "SD" ? "microSD" : s.type === "MMC" ? "eMMC" : s.type || s.block, `${s.name || ""} ${s.size_gb} ГБ`],
      ["Режим шины", s.timing ? `${s.timing}, ${s.clock_mhz} МГц, ${s.bus_bits} бит` : null],
      ["Дата выпуска", s.date],
    ]) + (slow ? `<p class="hint warnline">Карта работает в режиме high-speed (до ~23 МБ/с): быстрый режим UHS не согласовался.</p>` : "");
  }).join("");
  $("hw").innerHTML = [
    card("Устройство", kv([["Модель", h.model], ["Платформа", h.compatible.join(", ")],
      ["Часы реального времени", h.rtc], ["Работает", `${Math.floor(up / 3600)} ч ${Math.floor(up % 3600 / 60)} мин`]])),
    card("Процессор и память", kv([...h.cpu.map((c) => [c.name, `${c.cpus.length} ядра, ${c.min_mhz}–${c.max_mhz} МГц`]),
      ["Оперативная память", `${h.memory_mb} МБ`]])),
    card("Накопители", sd + kv([["NVMe (M.2)", h.nvme.length ? h.nvme.join(", ") : "не установлен"],
      ["PCIe", h.pci.length ? h.pci.map((p) => `${p.slot} ${p.id}`).join(", ") : "нет устройств"]])),
    card("Экран, графика, видео", kv([...h.displays.map((d) => [d.connector, d.mode]),
      ["GPU", `${(h.gpu.compatible || []).join(", ")} (${h.gpu.driver})`],
      ["Видеоблоки", h.video.join(", ")]])),
    card("Сеть и звук", kv([["Wi-Fi", h.wifi.driver ? `${h.wifi.driver}, ${h.wifi.mac}` : "нет"],
      ["Прошивка Wi-Fi", h.firmware.wifi], ["Bluetooth", h.bluetooth.join(", ") || "нет"],
      ["Звук", h.audio.join("; ")]])),
    card("USB и ввод", kv([...h.usb.map((u) => [u.id, `${u.name} (${u.speed_mbps} Мбит/с)`]),
      ...h.input.map((n) => ["Ввод", n])])),
    card("Датчики температуры", kv(h.thermal.map((t) => [t.name,
      `${t.c} °C; пороги: ${t.trips.map((x) => `${x.type} ${x.c}°`).join(", ")}`]))),
    card("Система", kv([["ChromiumOS", `${h.os.version} (R${h.os.milestone}, ${h.os.board})`],
      ["Ядро", h.kernel]])),
  ].join("");
}

// --- Wiring --------------------------------------------------------------------

document.querySelectorAll(".tab").forEach((b) => b.addEventListener("click", () => {
  document.querySelectorAll(".tab").forEach((x) => x.classList.toggle("active", x === b));
  document.querySelectorAll(".page").forEach((p) => (p.hidden = p.id !== b.dataset.tab));
  if (b.dataset.tab === "settings") loadSettings().catch((e) => toast(e.message));
  if (b.dataset.tab === "power") loadPower();
  if (b.dataset.tab === "hardware") loadHardware();
}));

// Refresh the power page while it is open (controls keep their state).
setInterval(() => {
  if (!$("power").hidden && !(document.activeElement || document.body).closest("#power-controls, #sleep")) loadPower();
}, 10000);

$("profiles").addEventListener("click", (e) => {
  const p = e.target.dataset.profile;
  if (!p) return;
  save(p === "custom" ? customBody() : { profile: p },
    () => "Режим: " + PROFILE_NAMES[p]);
});

["little_max", "big_max", "gpu_max", "cpu_governor", "gpu_governor"].forEach((id) =>
  $(id).addEventListener("change", () => save(customBody(), () => "Применено")));

$("migrate-go").addEventListener("click", () => {
  const sel = document.querySelector("input[name=migrate-target]:checked");
  if (!sel) return;
  if (!$("migrate-confirm").checked) { toast("Поставь галочку подтверждения"); return; }
  if (!confirm(`Всё на ${sel.value} будет стёрто, и туда будет скопирована эта система. Продолжить?`)) return;
  postMigrate({ target: sel.value, erase_confirmed: true },
    "Готово: перенос начнётся при следующей загрузке. Перезагрузи ноутбук.");
});
$("migrate-cancel").addEventListener("click", () => postMigrate({ target: null }, "Перенос отменён"));
$("migrate-reboot").addEventListener("click", () => {
  if (confirm("Перезагрузить ноутбук сейчас?")) postMigrate({ reboot: true }, "Перезагрузка…");
});

$("keys-save").addEventListener("click", () => {
  const google_keys = {
    api_key: $("api_key").value.trim(),
    client_id: $("client_id").value.trim(),
    client_secret: $("client_secret").value.trim(),
  };
  save({ google_keys }, () => {
    ["api_key", "client_id", "client_secret"].forEach((id) => ($(id).value = ""));
    return "Ключи сохранены. Выйди из сеанса, чтобы Chrome их подхватил.";
  });
});

$("keys-clear").addEventListener("click", () =>
  save({ google_keys: null }, () => "Ключи удалены (после выхода из сеанса)"));

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
