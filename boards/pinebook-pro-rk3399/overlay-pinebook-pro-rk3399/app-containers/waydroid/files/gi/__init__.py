# Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
# Distributed under the terms of the GNU General Public License v2

"""A stand-in for PyGObject's gi package with only GLib; see repository/GLib.py."""


def require_version(namespace, version):  # pylint: disable=unused-argument
    if namespace != "GLib":
        raise ValueError(f"Namespace {namespace} not available")
