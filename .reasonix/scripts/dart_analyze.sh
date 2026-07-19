#!/usr/bin/env bash
# dart analyze wrapper — 绕过 FVM shell wrapper 的 macOS provenance 权限问题
# 直接使用 Dart SDK 原生二进制
exec /Users/code/fvm/versions/3.44.6/bin/cache/dart-sdk/bin/dart analyze "$@"
