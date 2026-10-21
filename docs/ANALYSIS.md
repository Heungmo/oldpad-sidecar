# 분석 기록

Sidecar가 구형 iPad를 막는 방식과, 이 앱이 그것을 우회하는 방식을 정리한 문서입니다. 분석은 macOS 26.5.1 / 26.6 (M2 MacBook Air), iPad Air 2(iPadOS 15.8.4)에서 했고, 대부분 읽기 전용 정적 분석입니다. macOS가 업데이트되면 결과가 달라질 수 있습니다.

## 요약

- SidecarCore 안에 지원하지 않는 iPad 모델 15개가 하드코딩되어 있습니다.
- 이 목록으로 막는 곳은 연결을 처리하는 `SidecarDisplayAgent`가 아니라 **지원 기기를 거르는 UI 쪽 필터**입니다.
- `SidecarRelay`에서 받은 실제 기기 객체를 `SidecarDisplayManager`에 직접 넘기면 필터를 거치지 않고 연결됩니다.
- iPad의 모델 정보를 바꾸거나, 시스템 파일·프로세스 메모리를 수정하지 않습니다. SIP, SSV, AMFI도 건드리지 않습니다.

## 1. SidecarCore 추출

최신 macOS의 시스템 프레임워크는 파일로 존재하지 않고 dyld 공유 캐시 안에 들어 있습니다. [keith/dyld-shared-cache-extractor](https://github.com/keith/dyld-shared-cache-extractor)로 캐시에서 `SidecarCore`를 뽑아 분석했습니다. 추출한 Apple 바이너리는 재배포할 수 없어서 이 저장소에 넣지 않았습니다. 같은 방법으로 직접 추출하면 됩니다.

- 대상 파일은 arm64e 형식의 SidecarCore입니다 (`otool -hv`로 확인).
- `nm`으로 `_SidecarDisplayIsSupportediPadModel.unsupportedModels` 심볼을 찾았습니다.
- 이 심볼이 가리키는 배열에 모델 포인터 15개가 들어 있습니다.

## 2. 지원하지 않는 모델 목록

```text
iPad4,1  iPad4,2  iPad4,3  iPad4,4  iPad4,5
iPad4,6  iPad4,7  iPad4,8  iPad4,9
iPad5,1  iPad5,2  iPad5,3  iPad5,4
iPad6,11 iPad6,12
```

화이트리스트가 아니라 **명시적인 블랙리스트**입니다. 목록에 없는 모델은 지원하는 것으로 판정합니다 (예: `iPad7,5`는 지원). 판정 함수는 기기 모델을 목록 15개와 `isEqualToString:`으로 비교한 뒤 결과를 반전합니다.

```text
모델이 목록에 있음 → 비교 결과 1 → 반전 후 0 → 지원하지 않음
모델이 목록에 없음 → 비교 결과 0 → 반전 후 1 → 지원함
```

이것이 USB 연결과 기기 발견은 정상인데 로그에 `Device is supported: [NO]`가 찍히는 이유입니다.

## 3. 연결 경로

`SidecarDisplayAgent`를 읽기 전용으로 분석한 결과, 연결을 처리하는 메서드(`displayAgentConnectToDevice:withConfig:completion:`)에서 위 블랙리스트 함수를 직접 다시 호출하는 증거는 발견되지 않았습니다. 간접 검사 가능성까지 완전히 부정한 것은 아니지만, 실제 연결로 확인했습니다.

이 앱이 쓰는 경로는 다음과 같습니다.

```text
SidecarDevice allDevicesByForcingFetchFromRelay:   (SidecarRelay에서 실제 기기 객체 획득)
    ↓
UI의 지원 기기 목록 필터를 사용하지 않음
    ↓
SidecarDisplayManager connectToDevice:completion:
(또는 connectToDevice:withConfig:completion:)
    ↓
SidecarDisplayAgent가 세션과 가상 디스플레이 생성
```

기기 객체의 모델(`iPad5,3`)과 기기 유형은 끝까지 원래 값을 유지합니다.

## 4. 시도했지만 안 된 방법

- **`AllowAllDevices`**: `com.apple.sidecar.display`에 이 키를 켜도 우회되지 않았습니다. 환경설정 값과 SidecarCore 내부 모델 검사는 서로 다른 단계입니다.
- **Intel용 바이트 패치**: 공개된 기존 패치가 쓰는 `55 48 89 E5`(함수 시작), `B8 01 00 00 00 C3`(`mov eax, 1; ret`)는 x86_64 명령어입니다. arm64e SidecarCore는 포인터 인증 명령(`pacibsp`, `retab`)을 쓰므로 적용할 수 없고, 그대로 쓰면 바이너리가 손상될 수 있습니다.

## 5. 연결 설정 시험 결과

기본 연결 후 `-[SidecarDisplayManager configForDevice:]`로 읽은 협상 설정 (macOS 26.5.1 기준):

```text
size={960, 768}  scale=2.00  framerate=60  transport=2 (USB)
txMinBitrate=20000000  txMaxBitrate=40000000
```

- 비트레이트 값은 **bps 단위**입니다 (`20000000` = 20Mbps). 이 앱은 입력한 Mbps에 1,000,000을 곱해서 넘깁니다.
- 새 `SidecarDisplayConfig`의 기본값은 `size={0,0}`, `scale=0`이고 나머지는 비어 있습니다. 그래서 해상도와 배율은 반드시 채워야 합니다.
- 사이드바를 끄거나(`showSideBar=NO`) 영상 스트림이 `2048×1536`이 되는 설정은 `Video Stream Error: SidecarErrorDomain (-401)`로 즉시 실패했습니다. Air 2에서 전체 폭 영상 스트림은 현재 협상 조건으로 동작하지 않습니다.
- Touch Bar를 끄는 설정도 같은 오류가 났습니다.
- 이 앱으로 1024×768 @2x/30Hz/8Mbps 최대/저지연, 1280×960 @2x/60Hz를 시험했을 때는 연결이 열렸고 10초 세션 동안 `-401` 없이 유지됐습니다 (macOS 26.6).

## 6. 아직 모르는 것

- 저지연 옵션이 실제로 어떤 영향을 주는지
- 비트레이트를 바꿨을 때 화면 움직임 직후의 화질 회복 시간
- iPad Air 2 외 모델(iPad Air 1, mini 2·3·4, iPad 5세대)의 연결 여부
- 무선 연결 여부

## 안전 수칙

- 분석은 파일 읽기와 정적 분석 위주로 했고, `/System`, dyld 공유 캐시, Apple 프로세스 메모리는 수정하지 않았습니다.
- 실제 연결 시험은 시간 제한과 자동 해제를 두고 실행했습니다.
