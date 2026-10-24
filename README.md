# OldPad Sidecar

**버전 1.0.0** · [English](README.en.md) · [MIT 라이선스](LICENSE)

Apple이 Sidecar 사용을 막아 둔 구형 iPad(iPad Air 2 등)를 Mac의 보조 화면으로 연결하는 실험적인 macOS 앱입니다.

시스템 파일을 패치하지 않습니다. SIP를 끄거나 `/System`을 수정할 필요 없이, macOS가 제공하는 Sidecar 연결 기능을 직접 호출해서 연결합니다.

## 지원 환경

- Apple Silicon Mac
- 구형 iPad (아래 [공식적으로 막힌 모델](#공식적으로-막힌-모델) 참고)
- USB 케이블 연결

테스트한 환경은 M2 MacBook Air, macOS 26.5~26.6, iPad Air 2(iPadOS 15.8.4), USB 연결입니다. 다른 환경은 확인하지 못했습니다.

## 시작하기

1. iPad의 잠금을 풀고 USB 케이블로 Mac에 연결합니다.
2. Finder에서 iPad가 정상 인식되는지 확인합니다.
3. Mac과 iPad가 같은 Apple ID로 로그인되어 있는지 확인합니다.
4. 프로젝트를 내려받아 빌드합니다.

```sh
git clone https://github.com/Heungmo/oldpad-sidecar.git
cd oldpad-sidecar
./build_app.sh
```

빌드가 끝나면 프로젝트 폴더에 `OldPad Sidecar.app`이 생성됩니다. 앱을 열고 기기를 고른 뒤 `연결`을 누르면 됩니다.

## 사용법

### 기기 선택

앱을 열면 같은 Apple ID로 로그인된 기기를 자동으로 검색해 목록에 보여 줍니다. 기기 이름 대신 제품명(예: `iPad Air 2`)으로 표시되고, Sidecar가 공식적으로 막은 모델에는 `— 공식 미지원`이 붙습니다. 목록이 비어 있으면 `새로고침`을 누르세요. 마지막으로 고른 기기는 다음 실행 때도 기억합니다.

### 연결 설정

`연결 설정 직접 지정`을 끄면 Mac과 iPad가 협상한 기본값으로 연결합니다. 처음에는 이 상태로 쓰는 것을 권장합니다. 켜면 아래 항목을 지정할 수 있습니다.

| 항목 | 설명 |
|---|---|
| 해상도 (너비×높이), 배율 | 필수입니다. Air 2의 기본 협상값은 1024×768, 2x입니다. |
| 주사율 | Hz 단위입니다. 비우면 기본값(60Hz)을 씁니다. |
| 최소·최대 비트레이트 | Mbps 단위입니다. 비우면 기본값(20~40Mbps)을 씁니다. |
| 저지연 | 켜면 저지연 옵션을 요청합니다. 실제 효과는 확인하지 못했습니다. |

입력한 값은 `연결`을 누를 때 저장되어 다음 실행에도 유지됩니다. 연결에 성공하면 협상된 해상도와 배율을 기기별로 기억합니다.

## 공식적으로 막힌 모델

macOS의 SidecarCore에는 Sidecar를 거부하는 모델 목록(`unsupportedModels`)이 하드코딩되어 있습니다. macOS 26.5 기준으로 15개 식별자가 들어 있습니다.

| 식별자 | 제품 |
|---|---|
| iPad4,1 / 4,2 / 4,3 | iPad Air (1세대) |
| iPad4,4 / 4,5 / 4,6 | iPad mini 2 |
| iPad4,7 / 4,8 / 4,9 | iPad mini 3 |
| iPad5,1 / 5,2 | iPad mini 4 |
| iPad5,3 / 5,4 | iPad Air 2 |
| iPad6,11 / 6,12 | iPad (5세대) |

이 목록은 정적 분석으로 확인한 것이라 macOS 업데이트로 달라질 수 있습니다. 이 앱은 iPad Air 2에서만 직접 확인했고, 나머지 모델은 연결되는지 확인하지 못했습니다. 분석 과정은 [docs/ANALYSIS.md](docs/ANALYSIS.md)에 정리했습니다.

## 시도했지만 안 된 방법

- **`AllowAllDevices` 설정**: `defaults write com.apple.sidecar.display AllowAllDevices -bool true`를 켜도 모델 검사를 우회하지 못했습니다. 환경설정 값과 SidecarCore 안의 모델 검사는 서로 다른 단계입니다.
- **Intel Mac용 바이트 패치**: 이 Mac의 SidecarCore는 arm64e라 명령어 형식이 달라 적용할 수 없습니다. 무리하게 쓰면 바이너리가 손상될 수 있습니다.

## 알려진 제한

- 해상도를 너무 키우면 연결이 끊길 수 있습니다. Air 2에서 전체 폭 `2048×1536` 영상 스트림은 `-401` 오류로 실패했습니다. 1280×960 @2x는 10초 연결이 유지되는 것을 확인했습니다.
- 사이드바나 Touch Bar를 끄는 설정은 같은 오류가 나서 이 앱에서는 지원하지 않습니다. 연결한 뒤 macOS 디스플레이 설정에서 바꿀 수 있습니다.
- 저지연 옵션의 효과, 비트레이트를 바꿨을 때 화질 변화는 측정하지 못했습니다.
- 무선 연결은 불안정합니다.
- macOS 또는 iPadOS 버전에 따라 동작이 달라질 수 있습니다.

## 문제 해결

| 증상 | 확인할 것 |
|---|---|
| `기기를 이미 사용 중입니다 (-100)` | 다른 Sidecar 연결 앱이나 Sidecar 세션이 실행 중입니다. 먼저 종료하세요. |
| 기기 목록이 비어 있음 | iPad 잠금 해제, USB 신뢰, 같은 Apple ID 로그인을 확인하고 `새로고침`을 누르세요. |
| 연결 직후 끊김 | `연결 설정 직접 지정`을 끄고 기본값으로 연결해 보세요. |

## 참고한 프로젝트

- [ben-z/free-sidecar](https://github.com/ben-z/free-sidecar): 구형 기기에서 Sidecar를 풀어 주는 프로젝트입니다. 이 앱은 시스템 파일을 패치하지 않는 다른 방식을 쓰지만, 문제를 이해하는 데 참고했습니다.
- [keith/dyld-shared-cache-extractor](https://github.com/keith/dyld-shared-cache-extractor): macOS의 dyld 공유 캐시에서 SidecarCore를 추출하는 데 사용했습니다.

## 참고

이 프로젝트는 개인 실험용입니다. 비공개 프레임워크(`SidecarCore`)를 사용하므로 macOS 업데이트로 언제든 동작하지 않게 될 수 있고, 다른 기기에서의 동작은 보장하지 않습니다.

## 면책

이 프로젝트는 Apple과 관련이 없는 비공식 프로젝트이며, Apple의 후원이나 승인을 받지 않았습니다. Sidecar, iPad, iPadOS, macOS, Mac은 미국 및 다른 국가에서 Apple Inc.의 상표입니다. 이 저장소에는 Apple의 소스 코드나 바이너리가 포함되어 있지 않습니다.

이 앱은 본인이 소유한 기기에서 쓰는 것을 전제로 한 개인 실험이며, 사용에 따른 책임은 사용자에게 있습니다. 자세한 내용은 [MIT 라이선스](LICENSE)의 무보증 조항을 참고하세요.

## 라이선스

[MIT](LICENSE) © 2026 Heungmo
