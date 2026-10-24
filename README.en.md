# OldPad Sidecar

**Version 1.0.0** · [한국어](README.md) · [MIT License](LICENSE)

An experimental macOS app that connects older iPads that Apple blocks from Sidecar (such as the iPad Air 2) to your Mac as a second display.

It does not patch any system files. You don't need to disable SIP or modify `/System`; the app calls the Sidecar connection feature that macOS already provides.

## Requirements

- Apple Silicon Mac
- An older iPad (see [Officially blocked models](#officially-blocked-models))
- USB cable connection

Tested on an M2 MacBook Air, macOS 26.5–26.6, an iPad Air 2 (iPadOS 15.8.4), over USB. Other setups have not been verified.

## Getting started

1. Unlock the iPad and connect it to the Mac with a USB cable.
2. Check that the iPad shows up normally in Finder.
3. Make sure the Mac and the iPad are signed in to the same Apple ID.
4. Download and build the project.

```sh
git clone https://github.com/Heungmo/oldpad-sidecar.git
cd oldpad-sidecar
./build_app.sh
```

When the build finishes, `OldPad Sidecar.app` is created in the project folder. Open the app, pick a device, and press `연결` (Connect).

> The app's interface is currently in Korean.

## Usage

### Choosing a device

When the app opens, it searches for devices signed in to the same Apple ID and lists them. Devices are shown by product name (for example `iPad Air 2`) instead of the name you gave them, and models that Sidecar officially blocks are marked `— 공식 미지원` (officially unsupported). If the list is empty, press `새로고침` (Refresh). The device you picked last is remembered for the next launch.

### Connection settings

With `연결 설정 직접 지정` (Set connection settings manually) turned off, the app connects with the defaults negotiated between the Mac and the iPad. This is the recommended starting point. Turn it on to set the following:

| Setting | Description |
|---|---|
| Resolution (width × height), scale | Required. The default negotiated value on the iPad Air 2 is 1024×768 at 2x. |
| Refresh rate | In Hz. Leave empty to use the default (60 Hz). |
| Min / max bitrate | In Mbps. Leave empty to use the default (20–40 Mbps). |
| Low latency | Requests the low-latency option. Its actual effect has not been measured. |

The values you enter are saved when you press `연결` (Connect) and kept for the next launch. After a successful connection, the negotiated resolution and scale are remembered per device.

## Officially blocked models

SidecarCore in macOS has a hard-coded list of models that Sidecar rejects (`unsupportedModels`). As of macOS 26.5 it contains 15 identifiers.

| Identifier | Product |
|---|---|
| iPad4,1 / 4,2 / 4,3 | iPad Air (1st generation) |
| iPad4,4 / 4,5 / 4,6 | iPad mini 2 |
| iPad4,7 / 4,8 / 4,9 | iPad mini 3 |
| iPad5,1 / 5,2 | iPad mini 4 |
| iPad5,3 / 5,4 | iPad Air 2 |
| iPad6,11 / 6,12 | iPad (5th generation) |

This list comes from static analysis and may change with macOS updates. The app has only been verified on the iPad Air 2; whether the other models connect is unknown. The analysis is written up in [docs/ANALYSIS.md](docs/ANALYSIS.md) (in Korean).

## Things that didn't work

- **The `AllowAllDevices` setting**: turning on `defaults write com.apple.sidecar.display AllowAllDevices -bool true` did not get past the model check. The preference value and the model check inside SidecarCore are separate stages.
- **Byte patches made for Intel Macs**: SidecarCore on this Mac is arm64e, so the instruction format differs and these patches cannot be applied. Forcing one in could corrupt the binary.

## Known limitations

- Setting the resolution too high can break the connection. On the iPad Air 2, a full-width `2048×1536` video stream failed with error `-401`. 1280×960 at 2x stayed connected for a 10-second test.
- Turning off the sidebar or the Touch Bar causes the same error, so this app does not support it. You can change it in the macOS display settings after connecting.
- The effect of the low-latency option, and how the bitrate changes image quality, have not been measured.
- Wireless connections are unstable.
- Behavior may differ depending on the macOS or iPadOS version.

## Troubleshooting

| Symptom | What to check |
|---|---|
| `기기를 이미 사용 중입니다 (-100)` (device already in use) | Another Sidecar connection app or Sidecar session is running. Quit it first. |
| The device list is empty | Check that the iPad is unlocked, trusted over USB, and signed in to the same Apple ID, then press `새로고침` (Refresh). |
| The connection drops right after connecting | Turn off `연결 설정 직접 지정` and connect with the defaults. |

## Related projects

- [ben-z/free-sidecar](https://github.com/ben-z/free-sidecar): a project that unlocks Sidecar on older devices. This app takes a different approach that does not patch system files, but it was a useful reference for understanding the problem.
- [keith/dyld-shared-cache-extractor](https://github.com/keith/dyld-shared-cache-extractor): used to extract SidecarCore from the macOS dyld shared cache.

## Notes

This is a personal experiment. It uses a private framework (`SidecarCore`), so it may stop working at any time after a macOS update, and behavior on other devices is not guaranteed.

## Disclaimer

This is an unofficial project. It is not affiliated with, endorsed by, or sponsored by Apple. Sidecar, iPad, iPadOS, macOS, and Mac are trademarks of Apple Inc., registered in the U.S. and other countries. This repository does not contain any Apple source code or binaries.

The app is a personal experiment meant to be used with devices you own, and you use it at your own risk. See the no-warranty terms in the [MIT License](LICENSE).

## License

[MIT](LICENSE) © 2026 Heungmo
