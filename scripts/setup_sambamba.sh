#!/usr/bin/env bash
# Ensure sambamba works in the pixi environment.
# On macOS, the conda sambamba binary segfaults (TLS incompatibility).
# This script replaces it with a symlink to Homebrew's working binary.

PIXI_ENV_BIN="$CONDA_PREFIX/bin"

# sambamba prints version to stderr, not stdout

# Check if sambamba already works
"$PIXI_ENV_BIN/sambamba" --version &>/dev/null && {
    "$PIXI_ENV_BIN/sambamba" --version 2>&1 | grep -m1 '^sambamba '
    exit 0
}

# Conda binary segfaulted — try linking brew's version (must match pinned version)
PINNED_SAMBAMBA_VERSION="1.0.1"
BREW_PREFIX=$(brew --prefix sambamba 2>/dev/null || true)
if [ -n "$BREW_PREFIX" ] && [ -x "$BREW_PREFIX/bin/sambamba" ]; then
    brew_version=$("$BREW_PREFIX/bin/sambamba" --version 2>&1 | grep -m1 '^sambamba ')
    if [ "$brew_version" != "sambamba $PINNED_SAMBAMBA_VERSION" ]; then
        echo "WARNING: brew sambamba version mismatch. Expected $PINNED_SAMBAMBA_VERSION, got '$brew_version'. Install the pinned version with: brew install sambamba@$PINNED_SAMBAMBA_VERSION" >&2
        exit 1
    fi
    echo "Linking brew's sambamba into pixi env..."
    ln -sf "$BREW_PREFIX/bin/sambamba" "$PIXI_ENV_BIN/sambamba"
    if "$PIXI_ENV_BIN/sambamba" --version &>/dev/null; then
        echo "OK: $("$PIXI_ENV_BIN/sambamba" --version 2>&1 | grep -m1 '^sambamba ')"
        exit 0
    fi
fi

echo "WARNING: sambamba not available. Install via: brew install sambamba@1.0.1" >&2
exit 1
