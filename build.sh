#!/usr/bin/env bash
# Compile the Codex Tools CLI and install it as `ctc`.
# Clone the repo on macOS or Linux, then run: ./build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ -x "${HOME}/.cargo/bin/cargo" ]]; then
  export PATH="${HOME}/.cargo/bin:${PATH}"
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "需要 curl 才能安装 Rust 工具链。" >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "未找到 cargo，正在安装 Rust stable..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
fi

install_linux_build_deps() {
  [[ "$(uname -s)" == "Linux" ]] || return 0
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists webkit2gtk-4.1; then
    return 0
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Linux 编译需要 GTK/WebKit 开发包。请先安装 Tauri 的系统依赖后再运行 ./build.sh。" >&2
    exit 1
  fi

  local packages=(
    build-essential
    curl
    file
    pkg-config
    libssl-dev
    libgtk-3-dev
    libwebkit2gtk-4.1-dev
    libayatana-appindicator3-dev
    librsvg2-dev
    patchelf
  )
  echo "正在安装 Linux 编译依赖..."
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y "${packages[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
  else
    echo "请用 root 安装: apt-get install -y ${packages[*]}" >&2
    exit 1
  fi
}

install_linux_build_deps

if [[ "$(uname -s)" == "Darwin" ]] && ! command -v clang >/dev/null 2>&1; then
  echo "macOS 编译需要 Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

cargo build --release --manifest-path "${ROOT}/src-tauri/Cargo.toml" --bin codex-tools-cli

binary="${ROOT}/src-tauri/target/release/codex-tools-cli"
install_dir="${HOME}/.local/bin"
mkdir -p "${install_dir}"
ln -sfn "${binary}" "${install_dir}/ctc"
chmod +x "${binary}"

echo "已编译: ${binary}"
echo "已链接: ${install_dir}/ctc -> ${binary}"
case ":${PATH}:" in
  *":${install_dir}:"*) ;;
  *)
    echo "把下面这行加进 shell 配置后再开一个终端:"
    echo "  export PATH=\"${install_dir}:\$PATH\""
    ;;
esac
echo "用法: ctc switch <账号>"
