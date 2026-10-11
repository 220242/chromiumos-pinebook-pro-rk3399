// Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
// Distributed under the terms of the GNU General Public License v2
//
// The page of the pinebook-android service: sets Android (Waydroid) up,
// starts and stops it, lists and installs apps.

"use strict";

const TEXT = {
  en: {
    title: "Android",
    state_needs_setup: "Not set up",
    state_setting_up: "Setting up",
    state_stopped: "Stopped",
    state_starting: "Starting",
    state_running: "Running",
    state_stopping: "Stopping",
    state_offline: "Not answering",
    offline: "The pinebook-android service does not answer. It starts when you log in. " +
      "Its log is /var/log/pinebook-android.log, also on the card's FAT partition " +
      "(logs\\boot-NNNN\\run_pinebook-android.log.txt).",
    setup_intro: "Android apps run here in Waydroid (LineageOS 20, Android 13), each in its own window.",
    setup_first: "Setting up:",
    setup_partition: "adds an ANDROID-DATA partition in the free {free} at the end of the microSD card; ChromiumOS's partitions are not changed;",
    setup_reuse: "uses the ANDROID-DATA partition already on the card, with the apps and data from before;",
    setup_download: "downloads Android (about 1 GB; needs the internet) and starts it.",
    setup_time: "This takes 10 to 30 minutes. The laptop can be used meanwhile.",
    setup_play: "With Google Play",
    setup_play_hint: "Google then asks to register this device once; this page shows how.",
    setup_button: "Set up Android",
    setup_problem: "Android cannot be set up here:",
    no_space: "the card has {free} free after ChromiumOS, and Android needs at least {min}. Write the image to a larger card (16 GB or more).",
    check_binder: "the kernel has no binder: an image built with Android support is needed",
    check_waydroid: "Waydroid is not installed",
    check_wayland: "Chrome's Wayland server is not running (/run/chrome/wayland-0)",
    step_partition: "Adding the ANDROID-DATA partition…",
    step_format: "Formatting ANDROID-DATA…",
    step_download: "Looking up Android's images…",
    step_download_system: "Downloading Android (system image)…",
    step_download_vendor: "Downloading Android (vendor image)…",
    step_verify_system: "Checking the download…",
    step_verify_vendor: "Checking the download…",
    step_extract_system: "Unpacking…",
    step_extract_vendor: "Unpacking…",
    step_configure: "Configuring…",
    step_container: "Starting the container…",
    step_boot: "Starting Android… The first start takes a few minutes.",
    step_show: "Opening Android…",
    step_install: "Installing the app…",
    step_stop: "Stopping Android…",
    step_upload: "Sending {name}…",
    progress_mb: "{done} of {total} MB",
    btn_open: "Open Android",
    btn_start: "Start Android",
    btn_stop: "Stop",
    btn_install: "Install APK…",
    drop_hint: "Or drop an .apk file on this page.",
    install_app: "Install as an app",
    play_register: "Google Play works once this device is registered: show its ID, enter it at google.com/android/uncertified with your Google account, then stop and start Android. It can take a while to take effect.",
    play_show_id: "Show the device ID",
    play_add_text: "Android here has no Google Play. Adding it downloads Android's system image again; apps and data stay.",
    play_add: "Add Google Play",
    apps_title: "Apps",
    apps_empty: "Apps appear here once Android has started.",
    autostart: "Open Android when this page opens",
    limits: "No sound or camera yet.",
    log_title: "Log",
    details: "Details",
    err_no_disk: "Could not tell which disk the system runs from.",
    err_emmc: "The system runs from the eMMC. Android is set up only on a microSD card; the eMMC is left alone.",
    err_no_space: "Not enough free space on the card after ChromiumOS (at least 4 GB is needed).",
    err_gpt: "Could not add the ANDROID-DATA partition.",
    err_fsck: "The ANDROID-DATA file system has errors that could not be fixed.",
    err_unsupported: "This image lacks what Android needs.",
    err_no_wayland: "Chrome's Wayland server is not running (/run/chrome/wayland-0).",
    err_no_network: "Could not download Android. Check the internet connection and try again.",
    err_init_failed: "Could not download or unpack Android. Try again.",
    err_container_failed: "Android's container did not start.",
    err_bus_failed: "The D-Bus session bus for Android did not start.",
    err_session_failed: "Android did not start.",
    err_boot_timeout: "Android did not finish starting in 15 minutes.",
    err_install_failed: "The app was not installed.",
    err_not_apk: "That is not an APK file.",
    err_not_set_up: "Set Android up first.",
    err_not_running: "Start Android first.",
    err_no_android_id: "No device ID yet: wait until Google Play has started once, then try again.",
    err_busy: "Wait: Android is still busy with the previous command.",
    err_upload: "The file did not arrive in full.",
    err_command_failed: "A command failed.",
    err_internal: "Internal error in the service.",
    err_http: "The service answered: {detail}",
    err_unknown: "Something went wrong ({code}).",
    see_log: "The log below has the details.",
    notice_setup_done: "Android is set up.",
    notice_installed: "Installed: {detail}.",
    notice_install_sent: "{detail} was sent to Android, but the app is not in the list yet; see the log.",
  },
  ru: {
    title: "Android",
    state_needs_setup: "Не настроен",
    state_setting_up: "Настраивается",
    state_stopped: "Остановлен",
    state_starting: "Запускается",
    state_running: "Работает",
    state_stopping: "Останавливается",
    state_offline: "Не отвечает",
    offline: "Служба pinebook-android не отвечает. Она запускается после входа в систему. " +
      "Её журнал — /var/log/pinebook-android.log, копия на FAT-разделе карты " +
      "(logs\\boot-NNNN\\run_pinebook-android.log.txt).",
    setup_intro: "Android-приложения работают здесь через Waydroid (LineageOS 20, Android 13), каждое в своём окне.",
    setup_first: "Настройка:",
    setup_partition: "добавит раздел ANDROID-DATA в свободные {free} в конце карты microSD; разделы ChromiumOS не меняются;",
    setup_reuse: "возьмёт раздел ANDROID-DATA, который уже есть на карте, с прежними приложениями и данными;",
    setup_download: "скачает Android (около 1 ГБ, нужен интернет) и запустит его.",
    setup_time: "Это займёт от 10 до 30 минут. Ноутбуком при этом можно пользоваться.",
    setup_play: "С Google Play",
    setup_play_hint: "Тогда Google попросит один раз зарегистрировать устройство; как это сделать, покажет эта страница.",
    setup_button: "Настроить Android",
    setup_problem: "Здесь Android не настроить:",
    no_space: "после ChromiumOS на карте свободно {free}, а Android нужно не меньше {min}. Запишите образ на карту побольше (от 16 ГБ).",
    check_binder: "в ядре нет binder: нужен образ, собранный с поддержкой Android",
    check_waydroid: "Waydroid не установлен",
    check_wayland: "не запущен Wayland-сервер Chrome (/run/chrome/wayland-0)",
    step_partition: "Добавляю раздел ANDROID-DATA…",
    step_format: "Форматирую ANDROID-DATA…",
    step_download: "Ищу образы Android…",
    step_download_system: "Скачиваю Android (образ system)…",
    step_download_vendor: "Скачиваю Android (образ vendor)…",
    step_verify_system: "Проверяю загрузку…",
    step_verify_vendor: "Проверяю загрузку…",
    step_extract_system: "Распаковываю…",
    step_extract_vendor: "Распаковываю…",
    step_configure: "Настраиваю…",
    step_container: "Запускаю контейнер…",
    step_boot: "Запускаю Android… Первый запуск занимает несколько минут.",
    step_show: "Открываю Android…",
    step_install: "Устанавливаю приложение…",
    step_stop: "Останавливаю Android…",
    step_upload: "Передаю {name}…",
    progress_mb: "{done} из {total} МБ",
    btn_open: "Открыть Android",
    btn_start: "Запустить Android",
    btn_stop: "Остановить",
    btn_install: "Установить APK…",
    drop_hint: "Или перетащите файл .apk на эту страницу.",
    install_app: "Установить как приложение",
    play_register: "Google Play заработает, когда устройство будет зарегистрировано: покажите его номер, введите на google.com/android/uncertified под своим аккаунтом Google, затем остановите и снова запустите Android. Регистрация вступает в силу не сразу.",
    play_show_id: "Показать номер устройства",
    play_add_text: "Здесь Android без Google Play. Чтобы добавить его, образ system Android скачается заново; приложения и данные останутся.",
    play_add: "Добавить Google Play",
    apps_title: "Приложения",
    apps_empty: "Приложения появятся здесь после запуска Android.",
    autostart: "Открывать Android при открытии этой страницы",
    limits: "Звука и камеры пока нет.",
    log_title: "Журнал",
    details: "Подробности",
    err_no_disk: "Не удалось понять, с какого диска запущена система.",
    err_emmc: "Система запущена с eMMC. Android ставится только на карту microSD, eMMC не трогаем.",
    err_no_space: "На карте мало места после ChromiumOS (нужно не меньше 4 ГБ).",
    err_gpt: "Не удалось добавить раздел ANDROID-DATA.",
    err_fsck: "В файловой системе ANDROID-DATA ошибки, которые не удалось исправить.",
    err_unsupported: "В этом образе нет того, что нужно Android.",
    err_no_wayland: "Не запущен Wayland-сервер Chrome (/run/chrome/wayland-0).",
    err_no_network: "Не удалось скачать Android. Проверьте интернет и попробуйте снова.",
    err_init_failed: "Не удалось скачать или распаковать Android. Попробуйте снова.",
    err_container_failed: "Контейнер Android не запустился.",
    err_bus_failed: "Не запустилась шина D-Bus для Android.",
    err_session_failed: "Android не запустился.",
    err_boot_timeout: "Android не загрузился за 15 минут.",
    err_install_failed: "Приложение не установилось.",
    err_not_apk: "Это не файл APK.",
    err_not_set_up: "Сначала настройте Android.",
    err_not_running: "Сначала запустите Android.",
    err_no_android_id: "Номера пока нет: дождитесь, пока Google Play запустится хотя бы раз, и попробуйте снова.",
    err_busy: "Подождите: Android ещё выполняет предыдущую команду.",
    err_upload: "Файл передался не полностью.",
    err_command_failed: "Команда завершилась с ошибкой.",
    err_internal: "Внутренняя ошибка службы.",
    err_http: "Ответ службы: {detail}",
    err_unknown: "Что-то пошло не так ({code}).",
    see_log: "Подробности в журнале ниже.",
    notice_setup_done: "Android настроен.",
    notice_installed: "Установлено: {detail}.",
    notice_install_sent: "Файл {detail} передан в Android, но приложения пока нет в списке; загляните в журнал.",
  },
};

const LANG = (navigator.language || "en").toLowerCase().startsWith("ru") ? "ru" : "en";

function t(key, vars) {
  let s = TEXT[LANG][key] ?? TEXT.en[key] ?? key;
  for (const [k, v] of Object.entries(vars || {})) s = s.replaceAll("{" + k + "}", String(v));
  return s;
}

const $ = (id) => document.getElementById(id);

function gb(bytes) {
  const n = bytes / 1e9;
  return (LANG === "ru" ? n.toFixed(1).replace(".", ",") + " ГБ" : n.toFixed(1) + " GB");
}

function storage(key, fallback) {
  try {
    const v = localStorage.getItem(key);
    return v === null ? fallback : v === "1";
  } catch (e) {
    return fallback;
  }
}

function store(key, value) {
  try {
    localStorage.setItem(key, value ? "1" : "0");
  } catch (e) {
    // Private window: the setting lasts for this visit only.
  }
}

let status = null;       // the service's last /api/status
let offline = false;     // the service did not answer
let local = null;        // {kind, text, detail} from this page's last action
let uploading = null;    // file name while an APK is being sent
let timer = null;
let autostartDone = false;

// --- talking to the service ------------------------------------------------

async function post(path, body, headers) {
  const opts = { method: "POST", headers: { "X-Android-Launcher": "1", ...(headers || {}) } };
  if (body instanceof Blob) {
    opts.body = body;
  } else {
    opts.body = JSON.stringify(body || {});
    opts.headers["Content-Type"] = "application/json";
  }
  const r = await fetch(path, opts);
  const data = await r.json().catch(() => null);
  if (!r.ok) {
    throw (data && data.error) || { code: "http", detail: `${r.status} ${r.statusText}` };
  }
  return data;
}

async function act(path, body, headers) {
  local = null;
  try {
    const data = await post(path, body, headers);
    if (data && data.state) status = data;
    return data;
  } catch (e) {
    local = { kind: "error", ...errorText(e) };
    return null;
  } finally {
    render();
    schedule(300);
  }
}

async function refresh() {
  try {
    const r = await fetch("/api/status", { cache: "no-store" });
    if (!r.ok) throw new Error(String(r.status));
    status = await r.json();
    offline = false;
  } catch (e) {
    offline = true;
  }
  render();
  autostart();
  const busy = offline || uploading || (status && (status.busy || status.state === "starting"));
  schedule(busy ? 1000 : 4000);
}

function schedule(ms) {
  clearTimeout(timer);
  timer = setTimeout(refresh, ms);
}

function errorText(err) {
  const code = (err && err.code) || "unknown";
  const key = "err_" + code;
  let text = TEXT.en[key] ? t(key, err) : t("err_unknown", { code });
  if (!["not_apk", "busy", "not_set_up", "not_running", "no_android_id", "no_network"].includes(code)) {
    text += " " + t("see_log");
  }
  return { text, detail: (err && err.detail) || "" };
}

// --- actions ---------------------------------------------------------------

function start() {
  return act("/api/start");
}

function setup(googlePlay) {
  return act("/api/setup", { start: true, google_play: googlePlay });
}

async function installFile(file) {
  if (!file) return;
  if (!/\.apk$/i.test(file.name) && file.type !== "application/vnd.android.package-archive") {
    local = { kind: "error", ...errorText({ code: "not_apk", detail: file.name }) };
    render();
    return;
  }
  uploading = file.name;
  render();
  try {
    await act("/api/install", file, {
      "Content-Type": "application/vnd.android.package-archive",
      "X-File-Name": encodeURIComponent(file.name),
    });
  } finally {
    uploading = null;
    render();
  }
}

function autostart() {
  if (autostartDone || offline || !status) return;
  autostartDone = true;
  // Opening the page (or the installed app) opens Android, unless it is not
  // set up yet, busy, or failed the last time.
  if (!$("autostart").checked || status.busy || status.error) return;
  if (status.state === "stopped" || status.state === "running") start();
}

// --- rendering ---------------------------------------------------------------

function render() {
  const s = status || {};
  const state = offline ? "offline" : s.state || "offline";
  const busy = !offline && (s.busy || uploading || state === "starting");

  const badge = $("state");
  badge.textContent = t("state_" + state);
  badge.dataset.state = state;

  renderMessage(s);

  $("setup").hidden = offline || state !== "needs_setup" || Boolean(s.busy);
  if (!$("setup").hidden) renderSetup(s);

  $("progress").hidden = !busy;
  if (busy) renderProgress(s);

  const ready = !offline && !busy && (state === "stopped" || state === "running");
  $("controls").hidden = !ready;
  $("start-button").textContent = t(state === "running" ? "btn_open" : "btn_start");
  $("stop-button").hidden = state !== "running";

  // Google Play: how to register the device (it must be running), or how
  // to add Play to an Android set up without it.
  $("play").hidden = !ready || (s.google_play && state !== "running");
  $("play-on").hidden = !s.google_play;
  $("play-off").hidden = Boolean(s.google_play);
  if ($("play").hidden) $("play-id").hidden = true;

  $("apps").hidden = offline || !s.apps;
  if (s.apps) renderApps(s.apps);

  $("options").hidden = offline;
}

function renderMessage(s) {
  let m = null;
  if (offline) m = { kind: "error", text: t("offline") };
  else if (local) m = local;
  else if (s.error && !s.busy) m = { kind: "error", ...errorText(s.error) };
  else if (s.notice && !s.busy) {
    m = { kind: "notice", text: t("notice_" + s.notice.code, { detail: s.notice.detail || "" }) };
  }
  $("message").hidden = !m;
  if (!m) return;
  $("message").className = "message " + m.kind;
  $("message-text").textContent = m.text;
  $("message-details").hidden = !m.detail;
  $("message-detail").textContent = m.detail || "";
}

function renderSetup(s) {
  const setup = s.setup || {};
  const problems = [];
  for (const [name, ok] of Object.entries(s.checks || {})) {
    if (!ok && name !== "wayland") problems.push(t("check_" + name));
  }
  if (setup.error) problems.push(errorText(setup.error).text);
  else if (!setup.has_partition && setup.free_bytes < setup.min_free) {
    problems.push(t("no_space", { free: gb(setup.free_bytes), min: gb(setup.min_free) }));
  }
  $("setup-ok").hidden = problems.length > 0;
  $("setup-problem").hidden = problems.length === 0;
  const list = $("setup-problems");
  list.replaceChildren(...problems.map((p) => {
    const li = document.createElement("li");
    li.textContent = p;
    return li;
  }));
  $("setup-partition").textContent = setup.has_partition || setup.has_data
    ? t("setup_reuse")
    : t("setup_partition", { free: gb(setup.free_bytes || 0) });
}

function renderProgress(s) {
  const step = uploading ? "upload" : s.step || (s.busy === "stop" ? "stop" : "configure");
  $("step").textContent = t("step_" + step, { name: uploading || "" });
  const bar = $("bar");
  const p = s.progress;
  if (!uploading && p && p[1] > 0) {
    bar.max = p[1];
    bar.value = p[0];
    $("bar-text").textContent = t("progress_mb", {
      done: Math.round(p[0] / 1e6), total: Math.round(p[1] / 1e6),
    });
  } else {
    bar.removeAttribute("value");
    $("bar-text").textContent = "";
  }
}

let shownApps = "";

function renderApps(apps) {
  // All of them, Android's own (Settings, Files...) last: on ChromiumOS they
  // have no desktop counterparts.
  const key = JSON.stringify(apps);
  $("apps-empty").hidden = apps.length > 0;
  if (key === shownApps) return;
  shownApps = key;
  $("app-grid").replaceChildren(...apps.map((app) => {
    const li = document.createElement("li");
    const button = document.createElement("button");
    button.type = "button";
    button.title = app.package;
    const img = document.createElement("img");
    img.alt = "";
    img.width = 48;
    img.height = 48;
    img.src = app.icon ? `/icons/${app.package}.png` : "/icon.svg";
    const name = document.createElement("span");
    name.textContent = app.name;
    button.append(img, name);
    button.addEventListener("click", () => act("/api/launch", { package: app.package }));
    li.append(button);
    return li;
  }));
}

// --- the log -----------------------------------------------------------------

let logTimer = null;

async function loadLog() {
  clearTimeout(logTimer);
  if (!$("logbox").open) return;
  try {
    const r = await fetch("/api/log", { cache: "no-store" });
    const text = await r.text();
    const pre = $("log");
    const atEnd = pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 8;
    pre.textContent = text;
    if (atEnd) pre.scrollTop = pre.scrollHeight;
  } catch (e) {
    $("log").textContent = t("offline");
  }
  logTimer = setTimeout(loadLog, 3000);
}

// --- setup of the page ---------------------------------------------------------

function init() {
  document.documentElement.lang = LANG;
  for (const el of document.querySelectorAll("[data-t]")) el.textContent = t(el.dataset.t);
  document.title = t("title");

  const auto = $("autostart");
  auto.checked = storage("autostart", true);
  auto.addEventListener("change", () => store("autostart", auto.checked));

  $("setup-button").addEventListener("click", () => setup($("setup-play").checked));
  $("start-button").addEventListener("click", start);
  $("stop-button").addEventListener("click", () => act("/api/stop"));
  $("apk").addEventListener("change", (e) => {
    installFile(e.target.files[0]);
    e.target.value = "";
  });
  $("play-add-button").addEventListener("click", () => setup(true));
  $("play-id-button").addEventListener("click", async () => {
    const data = await act("/api/android-id");
    if (data && data.android_id) {
      $("play-id").textContent = data.android_id;
      $("play-id").hidden = false;
    }
  });
  $("logbox").addEventListener("toggle", loadLog);

  // An APK dropped anywhere on the page is installed.
  document.addEventListener("dragover", (e) => e.preventDefault());
  document.addEventListener("drop", (e) => {
    e.preventDefault();
    if (status && (status.state === "stopped" || status.state === "running")) {
      installFile(e.dataTransfer.files[0]);
    }
  });

  // Chrome offers to install the page as an app (a shelf icon for Android).
  let installEvent = null;
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault();
    installEvent = e;
    $("install-app").hidden = false;
  });
  $("install-app").addEventListener("click", async () => {
    if (!installEvent) return;
    installEvent.prompt();
    await installEvent.userChoice;
    installEvent = null;
    $("install-app").hidden = true;
  });

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  }
  refresh();
}

init();
