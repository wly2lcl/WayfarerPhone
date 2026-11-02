#!/usr/bin/env bash
# 构建 Android 正式包并校验签名。签名材料由发布负责人通过环境变量提供，不写入仓库。
set -euo pipefail

required=(WF_ANDROID_STORE_FILE WF_ANDROID_STORE_PASSWORD WF_ANDROID_KEY_ALIAS WF_ANDROID_KEY_PASSWORD)
missing=()
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    missing+=("$name")
  fi
done
if (( ${#missing[@]} > 0 )); then
  echo "缺少签名环境变量：${missing[*]}" >&2
  echo "示例：export WF_ANDROID_STORE_FILE=/绝对路径/wayfarer-release.jks" >&2
  exit 1
fi
if [[ ! -f "$WF_ANDROID_STORE_FILE" ]]; then
  echo "keystore 不存在：$WF_ANDROID_STORE_FILE" >&2
  exit 1
fi

cd "$(dirname "$0")/../../apps/mobile"

flutter build appbundle --release
flutter build apk --release

apk="build/app/outputs/flutter-apk/app-release.apk"
aab="build/app/outputs/bundle/release/app-release.aab"

if command -v jarsigner >/dev/null 2>&1; then
  jarsigner -verify "$aab" >/dev/null && echo "AAB 签名校验通过"
else
  echo "未找到 jarsigner，跳过 AAB 签名校验" >&2
fi

apksigner_bin=$(command -v apksigner || true)
if [[ -z "$apksigner_bin" ]]; then
  apksigner_bin=$(find "${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools" -name apksigner 2>/dev/null | sort -V | tail -1)
fi
if [[ -z "$apksigner_bin" ]]; then
  echo "未找到 apksigner，跳过 APK 签名校验" >&2
else
  "$apksigner_bin" verify --print-certs "$apk"
fi

echo "AAB: $aab"
echo "APK: $apk"
