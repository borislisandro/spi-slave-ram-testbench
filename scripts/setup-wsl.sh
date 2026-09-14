#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

packages=(build-essential curl git gtkwave jq make universal-ctags verilator z3)
commands=(curl git gtkwave jq make verilator z3)
missing=()

for command_name in "${commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done

if ((${#missing[@]})); then
    echo "Installing missing WSL tools: ${missing[*]}"
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
fi

if ! command -v verible-verilog-format >/dev/null 2>&1; then
    architecture=$(uname -m)
    case "$architecture" in
        x86_64) verible_arch=x86_64 ;;
        aarch64|arm64) verible_arch=arm64 ;;
        *) echo "Unsupported Verible architecture: $architecture" >&2; exit 1 ;;
    esac

    release=$(curl -fsSL https://api.github.com/repos/chipsalliance/verible/releases/latest | jq -r .tag_name)
    archive="verible-${release}-linux-static-${verible_arch}.tar.gz"
    temporary_dir=$(mktemp -d)
    trap 'rm -rf "$temporary_dir"' EXIT
    curl -fL "https://github.com/chipsalliance/verible/releases/download/${release}/${archive}" \
        -o "$temporary_dir/$archive"
    sudo tar -C /usr/local --strip-components=1 -xzf "$temporary_dir/$archive"
fi

git submodule update --init --recursive

verilator --version
z3 --version
gtkwave --version 2>&1 | sed -n '1p'
verible-verilog-format --version
