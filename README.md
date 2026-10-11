# OCBoost — RootHide / arm64 + arm64e

**Dev:** Nguyễn Minh, Nam Khang  
**Package ID:** `com.ngminh.ocboost`  
**Version:** `1.0.0`  
**Target:** RootHide, iOS 15+, `arm64` + `arm64e`

OCBoost is a Theos source project with a Sileo preferences bundle, four profiles, a focused-app list (up to five apps), a local CPU benchmark, and a 64-request HTTPS network benchmark.

## Included features

- Master on/off switch.
- Four modes: **Mát mẻ** (`cool`), **Cân bằng** (`balanced`), **Tối đa** (`maximum`), **Thông minh** (`smart`).
- Manually specify up to five app Bundle IDs. In `maximum` and `smart`, a selected foreground app receives an `NSProcessInfo` user-initiated activity hint. In `smart`, this hint is skipped when the device's thermal state is serious or critical.
- CPU microbenchmark, measuring a local math workload.
- Network benchmark using 64 concurrent HTTPS requests to Cloudflare's public speed-test endpoint.
- GitHub Actions workflow to build a RootHide `.deb` for both requested architectures and attach the `.deb` to a GitHub Release when a `v*` tag is pushed.

## Important limitations

This is **not a hardware overclock driver**. Generic iOS tweaks cannot safely set CPU/GPU clock frequencies without device- and iOS-version-specific kernel support. These sources do not patch the kernel, change voltage, or claim to force frequencies.

The profiles are implemented conservatively:

- **Mát mẻ:** no performance activity hint; relies on iOS thermal/power management.
- **Cân bằng:** no performance activity hint; leaves the normal iOS policy in place.
- **Tối đa:** sends an activity hint while a selected app is foregrounded; it does not allocate all CPU/RAM exclusively to that app.
- **Thông minh:** same cooperative hint for selected apps only while thermal state is nominal/fair.

The network feature is a **test**, not a system-wide network accelerator. Sixty-four parallel HTTP requests do not necessarily create 64 TCP connections because the networking stack/server may use HTTP/2 multiplexing or limit concurrency. It does not modify Wi-Fi/cellular settings or speed up all apps.

OCBoost intentionally does **not** kill all daemons, background apps, or iOS processes. Doing so can break telephony, SpringBoard, notifications, storage, and other core services, and can cause instability or boot loops.

## Build the `.deb`

Use a macOS environment with Xcode command line tools, Homebrew, and RootHide Theos installed:

```sh
export THEOS="$HOME/theos"
brew install ldid dpkg
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

The resulting package should appear under `packages/*.deb`. `ARCHS = arm64 arm64e` is set in `Makefile`.

## Build using GitHub Actions

1. Create a new GitHub repository and upload/push this project.
2. Open **Actions** and run **Build OCBoost (RootHide)**, or push to `main`/`master`.
3. Download the `OCBoost-RootHide-deb` artifact from the workflow run.
4. To attach the `.deb` to a Release, create and push a version tag, for example:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The GitHub workflow builds the package; it does not publish to a repository/account automatically unless this project is pushed to your own GitHub repository.

## Choosing apps

In Settings → OCBoost → **Chọn ứng dụng (tối đa 5)**, enter comma-separated Bundle IDs. Examples that may vary by app/region/version:

- TikTok: `com.zhiliaoapp.musically`
- YouTube: `com.google.ios.youtube`
- Instagram: `com.burbn.instagram`

Verify a Bundle ID on your own device before relying on it.

## Project layout

```text
OCBoost/
├── Makefile
├── control
├── Tweak.m
├── Preferences/
│   ├── OCBoostRootListController.m
│   └── Root.plist
├── layout/Library/PreferenceLoader/Preferences/OCBoostPrefs.plist
├── .github/workflows/build.yml
└── build.sh
```
