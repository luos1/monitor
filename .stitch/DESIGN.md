# 아이패드미러 DESIGN.md

Google Stitch 호환 디자인 시스템. 에이전트와 사람이 같은 토큰으로 iPad/Mac UI를 구현한다.

## Product

- Name: 아이패드미러
- Pair: iPad sender + Mac receiver. 한쪽만으로는 완성되지 않는다.
- Tone: 차분하고 신뢰감 있는 유틸리티. 게임 UI가 아니라 작업용 화면 미러.
- Platforms: iPadOS 17+, macOS 14+
- Font implementation: San Francisco (Apple system). Stitch 목업은 Be Vietnam Pro.

## Color tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| primary | `#3B5BDB` | `#91A7FF` | 브랜드, 선택, 보조 CTA |
| on-primary | `#FFFFFF` | `#1A237E` | primary 위 텍스트 |
| primary-container | `#DBE4FF` | `#2B3A7A` | 칩, 번호 배지 |
| live | `#E03131` | `#FF6B6B` | 방송 중, 시작 CTA |
| on-live | `#FFFFFF` | `#FFFFFF` | live 위 텍스트 |
| success | `#2F9E44` | `#69DB7C` | 연결됨 |
| warning | `#F08C00` | `#FFC078` | 동반 앱 필요 안내 |
| surface | `#F4F6FB` | `#10131A` | 페이지 배경 |
| surface-container | `#FFFFFF` | `#1B202A` | 카드 |
| surface-container-high | `#EAEEF8` | `#252B38` | 칩, 사이드바 |
| on-surface | `#151923` | `#F2F4F8` | 본문 |
| on-surface-variant | `#5C6474` | `#A8B0C0` | 보조 문구 |
| outline | `#D5DBE8` | `#343B4A` | 카드 테두리 |
| canvas | `#0B0D12` | `#0B0D12` | 미러 스테이지 |

Background wash: light `linear-gradient(180deg, #EEF2FF 0%, #F4F6FB 42%, #F8F4F1 100%)`.
Dark wash: `linear-gradient(180deg, #161B2C 0%, #10131A 50%, #17120F 100%)`.

## Typography

| Role | Size | Weight | Tracking |
| --- | --- | --- | --- |
| display | 34 | Semibold | -0.4 |
| title | 22 | Semibold | -0.2 |
| headline | 17 | Semibold | 0 |
| body | 16 | Regular | 0 |
| caption | 13 | Medium | 0.1 |

한 화면에 display는 한 번만. 본문은 짧고 한 줄 원칙을 우선한다.

## Spacing and shape

- Space scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40
- Page padding: 24 (iPad), 20 (Mac sidebar)
- Card padding: 20
- Card radius: 24
- Chip radius: 999
- Button radius: 20
- Button height: 56 primary, 48 secondary
- Icon circle: 56 / 88
- Shadow: `0 12px 32px rgba(21, 25, 35, 0.08)`

## Components

- **Brand mark**: 인디고 원 + `rectangle.split.2x1` 심볼.
- **Usage chip**: 남은 시간을 캡슐로. 10분 이하면 warning.
- **Status orb**: idle=primary, live=live + 펄스.
- **Companion banner**: warning 톤, 동반 앱이 필요하다는 사실만. 위협하지 않는다.
- **Step card**: 원형 번호 + 제목 + 한 줄 설명.
- **Device row**: 이름, 전송 경로, 선택 시 primary-container.
- **Mirror bezel**: 16 radius 검정 스테이지, 안쪽 여백 8.
- **Paywall**: 잠금 마크, 광고 연장 primary, 구매/도네이션은 URL이 있을 때만 활성.

## Screens

1. iPad 온보딩
2. iPad 홈 (방송 제어)
3. iPad 잠금 (60분 소진)
4. Mac 온보딩
5. Mac 수신 (목록 + 미러)
6. Mac 잠금

## Motion

- 상태 전환 220ms ease-out
- live 펄스 1.6s
-  entice 애니메이션 없음. 작업 방해 금지.

## Do / Don't

- Do: iPad와 Mac을 한 제품의 두 면으로 보여 준다.
- Do: 남은 시간과 연결 상태를 항상 보이게 한다.
- Don't: "URL 대기" 같은 미완성 문구를 출시 UI에 남기지 않는다.
- Don't: 본문을 경고 배너로 도배하지 않는다.
