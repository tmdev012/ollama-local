# setup-box — self-contained dev toolchain driven by llama3.2
# No Claude needed after this. llama3.2 owns setup tasks inside.
#
# Includes: Java 17, Android SDK (platform-tools, API 34, build-tools 34),
#           ADB, libimobiledevice (iOS), ollama + llama3.2, sashi CLI
#
# Build:  docker compose build
# Run:    docker compose up -d  →  docker exec -it setup-box zsh

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    ANDROID_HOME=/opt/android/sdk \
    ANDROID_SDK_ROOT=/opt/android/sdk \
    IOS_HOME=/opt/ios \
    OLLAMA_HOST=http://ollama:11434 \
    PATH="/usr/lib/jvm/java-17-openjdk-amd64/bin:/opt/android/sdk/cmdline-tools/latest/bin:/opt/android/sdk/platform-tools:/opt/android/sdk/build-tools/35.2.0:/root/.local/bin:/usr/local/bin:$PATH"

# ── Base tools ───────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless \
    adb \
    wget curl unzip git zsh \
    libimobiledevice-utils ideviceinstaller ifuse usbmuxd \
    sqlite3 jq make build-essential \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# ── Android SDK cmdline-tools ─────────────────────────────────────
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    wget -q -O /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/android-cmd && \
    mv /tmp/android-cmd/cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
    rm -f /tmp/cmdline-tools.zip && \
    yes | sdkmanager --licenses > /dev/null 2>&1 || true && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;35.2.0"

# ── sashi CLI (copy from repo) ────────────────────────────────────
COPY ../../sashi /usr/local/bin/sashi
RUN chmod +x /usr/local/bin/sashi

# ── iOS dirs ─────────────────────────────────────────────────────
RUN mkdir -p $IOS_HOME/{ipa,mnt,logs}

# ── zsh as default shell ──────────────────────────────────────────
RUN chsh -s /usr/bin/zsh root

WORKDIR /workspace
CMD ["zsh"]
