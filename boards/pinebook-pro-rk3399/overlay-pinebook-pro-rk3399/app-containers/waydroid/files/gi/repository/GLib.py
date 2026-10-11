# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

"""The parts of GLib that Waydroid uses, without PyGObject.

PyGObject needs GObject introspection, which is hard to cross-compile and is
not built for ChromiumOS boards. Waydroid only needs GLib's main loop (which
dbus-python and libgbinder dispatch their events through), Unix signal, idle
and timeout sources, and key files for the .desktop files of Android's apps.
The main loop functions call libglib directly through ctypes, so they run the
same default main context as dbus-python and libgbinder. KeyFile is plain
Python. Waydroid finds this package before any installed PyGObject because
it lives next to waydroid.py.
"""

import ctypes
import enum
import threading
import traceback

PRIORITY_HIGH = -100
PRIORITY_DEFAULT = 0
PRIORITY_HIGH_IDLE = 100
PRIORITY_DEFAULT_IDLE = 200
PRIORITY_LOW = 300

_glib = ctypes.CDLL("libglib-2.0.so.0")
_SourceFunc = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)
_DestroyNotify = ctypes.CFUNCTYPE(None, ctypes.c_void_p)


def _declare(name, restype, *argtypes):
    func = getattr(_glib, name)
    func.restype = restype
    func.argtypes = list(argtypes)


_declare("g_main_loop_new", ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int)
_declare("g_main_loop_run", None, ctypes.c_void_p)
_declare("g_main_loop_quit", None, ctypes.c_void_p)
_declare("g_main_loop_is_running", ctypes.c_int, ctypes.c_void_p)
_declare("g_idle_add_full", ctypes.c_uint,
         ctypes.c_int, _SourceFunc, ctypes.c_void_p, _DestroyNotify)
_declare("g_timeout_add_full", ctypes.c_uint,
         ctypes.c_int, ctypes.c_uint, _SourceFunc, ctypes.c_void_p, _DestroyNotify)
_declare("g_timeout_add_seconds_full", ctypes.c_uint,
         ctypes.c_int, ctypes.c_uint, _SourceFunc, ctypes.c_void_p, _DestroyNotify)
_declare("g_unix_signal_add_full", ctypes.c_uint,
         ctypes.c_int, ctypes.c_int, _SourceFunc, ctypes.c_void_p, _DestroyNotify)
_declare("g_source_remove", ctypes.c_int, ctypes.c_uint)
_declare("g_set_prgname", None, ctypes.c_char_p)

# Sources carry a key into this table rather than a Python object, so GLib
# never holds a pointer the garbage collector does not know about.
_lock = threading.Lock()
_callbacks = {}
_last_key = 0


def _register(function, user_data):
    global _last_key
    with _lock:
        _last_key += 1
        _callbacks[_last_key] = (function, user_data)
        return _last_key


@_SourceFunc
def _dispatch(key):
    with _lock:
        entry = _callbacks.get(key)
    if entry is None:
        return 0
    function, user_data = entry
    try:
        return 1 if function(*user_data) else 0
    except Exception:  # pylint: disable=broad-except
        # As PyGObject does: report it, and remove the source.
        traceback.print_exc()
        return 0


@_DestroyNotify
def _destroy(key):
    with _lock:
        _callbacks.pop(key, None)


def idle_add(function, *user_data, priority=PRIORITY_DEFAULT_IDLE):
    return _glib.g_idle_add_full(priority, _dispatch,
                                 _register(function, user_data), _destroy)


def timeout_add(interval, function, *user_data, priority=PRIORITY_DEFAULT):
    return _glib.g_timeout_add_full(priority, interval, _dispatch,
                                    _register(function, user_data), _destroy)


def timeout_add_seconds(interval, function, *user_data, priority=PRIORITY_DEFAULT):
    return _glib.g_timeout_add_seconds_full(priority, interval, _dispatch,
                                            _register(function, user_data), _destroy)


def unix_signal_add(priority, signum, handler, *user_data):
    return _glib.g_unix_signal_add_full(priority, signum, _dispatch,
                                        _register(handler, user_data), _destroy)


def source_remove(tag):
    return bool(_glib.g_source_remove(tag))


def set_prgname(name):
    _glib.g_set_prgname(name.encode())


class MainLoop:
    """A main loop on the default main context."""

    def __init__(self, context=None, is_running=False):
        if context is not None:
            raise NotImplementedError("only the default main context is supported")
        # Never freed: GLib keeps it alive while it runs, and Waydroid makes
        # a handful per process.
        self._loop = _glib.g_main_loop_new(None, 1 if is_running else 0)

    def run(self):
        # ctypes releases the GIL for the call; callbacks take it back.
        _glib.g_main_loop_run(self._loop)

    def quit(self):
        _glib.g_main_loop_quit(self._loop)

    def is_running(self):
        return bool(_glib.g_main_loop_is_running(self._loop))


class GError(Exception):
    def __init__(self, message="", domain="", code=0):
        super().__init__(message)
        self.message = message
        self.domain = domain
        self.code = code


Error = GError


class KeyFileFlags(enum.IntFlag):
    NONE = 0
    KEEP_COMMENTS = 1
    KEEP_TRANSLATIONS = 2


_ESCAPES = {"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\", ";": ";"}


def _unescape(value, separator=False):
    """GLib's key file escapes; with separator, also splits on bare ';'."""
    out, item, i = [], [], 0
    while i < len(value):
        c = value[i]
        if c == "\\" and i + 1 < len(value):
            item.append(_ESCAPES.get(value[i + 1], "\\" + value[i + 1]))
            i += 2
            continue
        if separator and c == ";":
            out.append("".join(item))
            item = []
        else:
            item.append(c)
        i += 1
    if not separator:
        return "".join(item)
    if item:
        out.append("".join(item))
    return out


def _escape(value, separator=False):
    """As g_key_file_set_string(): leading blanks, backslashes, line breaks
    (and ';' in lists) are escaped; other blanks are kept."""
    out = []
    leading = True
    for c in value:
        if leading and c in " \t":
            out.append("\\s" if c == " " else "\\t")
            continue
        leading = False
        out.append({"\\": "\\\\", "\n": "\\n", "\r": "\\r"}.get(c)
                   or ("\\;" if separator and c == ";" else c))
    return "".join(out)


class KeyFile:
    """GLib's key file format (.desktop files). Comments, translations and
    the order of groups and keys are kept."""

    def __init__(self):
        self._head = []      # comment lines before the first group
        self._groups = {}    # group -> [("#", comment) or (key, raw value)]

    def load_from_file(self, path, flags=KeyFileFlags.NONE):
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except (OSError, UnicodeDecodeError) as e:
            raise GError(str(e), "g-file-error-quark", 4) from None
        return self.load_from_data(text, len(text), flags)

    def load_from_data(self, data, length=-1, flags=KeyFileFlags.NONE):
        head, groups, entries = [], {}, None
        for number, line in enumerate(data.splitlines(), 1):
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith("#"):
                (head if entries is None else entries).append(("#", line))
            elif stripped.startswith("[") and stripped.endswith("]"):
                entries = groups.setdefault(stripped[1:-1], [])
            elif "=" in line and entries is not None:
                key, value = line.split("=", 1)
                entries.append((key.strip(), value.lstrip()))
            else:
                raise GError(f"Key file contains line {number} which is not a "
                             "key-value pair, group, or comment",
                             "g-key-file-error-quark", 1)
        self._head, self._groups = head, groups
        return True

    def to_data(self):
        lines = [line for _, line in self._head]
        for n, (group, entries) in enumerate(self._groups.items()):
            if n:
                lines.append("")
            lines.append(f"[{group}]")
            lines += [line if key == "#" else f"{key}={line}" for key, line in entries]
        data = "\n".join(lines) + "\n"
        return data, len(data)

    def save_to_file(self, path):
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(self.to_data()[0])
        except OSError as e:
            raise GError(str(e), "g-file-error-quark", 4) from None
        return True

    def get_groups(self):
        groups = list(self._groups)
        return groups, len(groups)

    def has_group(self, group):
        return group in self._groups

    def get_keys(self, group):
        keys = [k for k, _ in self._entries(group) if k != "#"]
        return keys, len(keys)

    def has_key(self, group, key):
        return any(k == key for k, _ in self._entries(group))

    def remove_group(self, group):
        self._entries(group)
        del self._groups[group]
        return True

    def get_value(self, group, key):
        for k, value in self._entries(group):
            if k == key:
                return value
        raise GError(f'Key file does not have key "{key}" in group "{group}"',
                     "g-key-file-error-quark", 3)

    def set_value(self, group, key, value):
        entries = self._groups.setdefault(group, [])
        for i, (k, _) in enumerate(entries):
            if k == key:
                entries[i] = (key, value)
                return
        # As GLib does: before the comments at the end of the group, which
        # belong to the next group's header.
        pos = len(entries)
        while pos and entries[pos - 1][0] == "#":
            pos -= 1
        entries.insert(pos, (key, value))

    def get_string(self, group, key):
        return _unescape(self.get_value(group, key))

    def set_string(self, group, key, string):
        self.set_value(group, key, _escape(string))

    def get_string_list(self, group, key):
        return _unescape(self.get_value(group, key), separator=True)

    def set_string_list(self, group, key, strings):
        self.set_value(group, key, "".join(_escape(s, True) + ";" for s in strings))

    def get_boolean(self, group, key):
        value = self.get_value(group, key).strip()
        if value in ("true", "1"):
            return True
        if value in ("false", "0"):
            return False
        raise GError(f'Key file contains key "{key}" with value "{value}" '
                     "which is not a boolean", "g-key-file-error-quark", 5)

    def set_boolean(self, group, key, value):
        self.set_value(group, key, "true" if value else "false")

    def _entries(self, group):
        try:
            return self._groups[group]
        except KeyError:
            raise GError(f'Key file does not have group "{group}"',
                         "g-key-file-error-quark", 4) from None
