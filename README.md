<div align="center">

<br/>

# 소우주 (Microcosm)

[![App Store](https://img.shields.io/badge/App%20Store-Download-blue?style=flat-square&logo=apple&logoColor=white)](https://apps.apple.com/kr/app/%EC%86%8C%EC%9A%B0%EC%A3%BC/id6760713435)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-000000?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)

**하루의 순간을, 하나의 별로 남기세요.**

스쳐 지나가는 감정과, 기억하고 싶은 장면들 —
소우주에서는 하루하루가 별이 되어 당신만의 밤하늘에 차곡차곡 쌓입니다.

그리고 이루고 싶은 목표는 별자리로 그려보세요.
작은 별들이 하나씩 이어질 때, 당신만의 별자리가 완성됩니다.

오늘의 빛은 사라지지 않고, 당신의 소우주에 그대로 남아 있습니다.

<br/>

</div>

<br/>

## Features

| 기능 | 설명 |
|------|------|
| **별 기록** | 하루의 기록을 작성하면 AI가 감정을 분석하여 고유한 색, 밝기, 반짝임을 가진 별로 생성 |
| **월별 은하** | 기록이 월 단위로 은하에 모여 SpriteKit 씬에서 인터랙티브하게 탐색 가능 |
| **별자리 목표** | 88개 실제 별자리 중 선택하여 목표를 설정하고, 하위 목표 달성 시 별이 하나씩 채워짐 |
| **프로필 통계** | 감정 색상 분포, 기록 수 등 자신의 기록 패턴을 시각적으로 확인 |
| **온보딩** | 7단계 인터랙티브 가이드로 소우주 세계관에 자연스럽게 진입 |

### AI 감정 분석

사용자가 기록을 작성하면 OpenAI API(`gpt-4o-mini`)가 텍스트의 감정을 분석합니다.

```
기록 텍스트 → OpenAI 감정 분석 → StarVisualProfile 생성
                                   ├─ 색상 (primary, secondary, glow)
                                   ├─ 크기, 밝기
                                   ├─ 반짝임 (속도, 강도)
                                   └─ 움직임 (진폭, 속도)
```

같은 "행복"이라도 글의 뉘앙스에 따라 별의 빛이 달라집니다.

<br/>

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI** | SwiftUI + SpriteKit (Metal Shader) |
| **State Management** | TCA (The Composable Architecture) 1.17+ |
| **Backend** | Firebase (Auth, Firestore) |
| **Auth** | Google Sign-In, Apple Sign-In |
| **AI** | OpenAI API (gpt-4o-mini) |
| **Account Deletion** | Firebase Cloud Functions (Node.js) |
| **Build System** | Tuist (Modular Architecture) |
| **Code Quality** | SwiftLint |
| **Minimum iOS** | iOS 17.0+ |

<br/>

## Architecture

TCA 기반 단방향 아키텍처로, 모든 Feature는 독립된 모듈로 분리되어 있습니다.

```
Action → Reducer → State → View
            ↓
     Dependency Client (Firebase, OpenAI)
```

<br/>

## Module Dependency Graph

```
┌─────────────────────────────────────────────────────────┐
│                         App                             │
└──────────────────────────┬──────────────────────────────┘
                           │
                    Feature.Root
                     ┌─────┴─────┐
              Feature.Auth   Feature.Main
                         ┌───────┼───────┐
                   Universe  Constellation  Profile
                      │           │           │
                ┌─────┤           │       ┌───┤
           Onboarding  Nickname   │    Nickname │
                │         │       │       │     │
                ├─────────┴───────┴───────┘     │
                ▼                                ▼
┌──────────────────────────────┐  ┌──────────────────────┐
│          Domain              │  │       Shared         │
│  ┌────────┐  ┌───────────┐  │  │  ┌─────────────────┐ │
│  │ Entity │←─│  Client   │  │  │  │  DesignSystem   │ │
│  │        │  │           │  │  │  │  RecordVisuals  │ │
│  │        │  │ • Auth    │  │  │  │  Util           │ │
│  │        │  │ • User    │  │  │  └─────────────────┘ │
│  │        │  │ • Record  │  │  └──────────────────────┘
│  │        │  │ • Goal    │  │
│  │        │  │ • OpenAI  │  │
│  └────────┘  └───────────┘  │
└──────────────────────────────┘
                  │
        ┌─────────┴─────────┐
    Firebase SDK      OpenAI API
    Google Sign-In
```

<br/>

## Project Structure

```
Projects/
├── App/                           # 앱 진입점
├── Feature/                       # 기능 모듈
│   ├── Root                       # 인증 상태 기반 네비게이션
│   ├── Auth                       # 소셜 로그인 (Google, Apple)
│   ├── Onboarding                 # 7단계 인터랙티브 온보딩
│   ├── Main                       # 탭 컨테이너 (Universe, Constellation, Profile)
│   ├── Universe                   # 기록 → 별 생성, 월별 은하 뷰
│   ├── Constellation              # 88개 별자리 기반 목표 관리
│   ├── Profile                    # 프로필, 감정 통계
│   └── Nickname                   # 닉네임 입력/검증 (재사용)
├── Domain/
│   ├── Entity                     # 데이터 모델 (Record, Goal, Constellation)
│   └── Client                     # 의존성 클라이언트 (Auth, User, Record, Goal, OpenAI)
├── Core/
│   └── FirebaseKit                # Firebase 인프라 래퍼
└── Shared/
    ├── DesignSystem               # 색상, 타이포그래피, 공통 컴포넌트
    ├── RecordVisuals              # 별 시각화 유틸리티
    └── Util                       # 포맷 헬퍼, 해시 유틸
```

<br/>

## App Flow

```
Splash → Auth Check
            ├─ 미인증 → 로그인 (Google / Apple)
            └─ 인증됨 → Main
                        ├─ 온보딩 미완료 → 7단계 가이드
                        └─ 메인 탭
                            ├─ Universe: 기록 작성 → AI 분석 → 별 생성 → 월별 은하
                            ├─ Constellation: 별자리 선택 → 목표 설정 → 달성 추적
                            └─ Profile: 감정 통계, 닉네임 변경, 계정 관리
```

<br/>

## AI Tool Usage

이 프로젝트는 **Claude Code** 기반의 커스텀 AI 개발 워크플로우(**하네스 엔지니어링**)를 설계하여 개발되었습니다.

### 하네스 엔지니어링

요구사항 분석부터 PR 준비까지, 10개의 전문 에이전트와 11개의 스킬로 구성된 iOS 개발 파이프라인을 직접 설계했습니다.
작업 규모에 따라 **light / balanced / full** 모드로 유연하게 운영되며, 리뷰(reviewer)와 QA(qa)는 스킵 불가능한 필수 검증 게이트입니다.

```
분석 → 설계 → 구현 + 테스트 → 리뷰 (필수) → QA (필수) → 문서화 + 커밋
                                                              │
                                          ┌───────────────────┤ (full 모드 시)
                                     env-checker       release-analyst
                                    (환경 검증)       (심사 리스크 분석)
```

| 모드 | 적용 기준 | 범위 |
|------|----------|------|
| **light** | 단순 수정, 오타, 설정 변경 | 구현 → 리뷰 → QA |
| **balanced** | 일반 기능 개발 (기본값) | 분석 → 설계 → 구현 + 테스트 → 리뷰 → QA → 문서화 + 커밋 |
| **full** | 대규모 변경, 신규 모듈 | balanced + env-checker + release-analyst (PR 전 게이트) |

### 활용 내역

- **아키텍처 설계** — 모듈 분리 전략, 의존성 그래프 설계
- **TCA Feature 구현** — Reducer, State, Action, View 코드 작성
- **AI 연동** — OpenAI API 클라이언트 및 프롬프트 엔지니어링
- **TDD 테스트** — 각 Client 및 Feature에 대한 단위 테스트
- **버그 수정** — 계정 삭제, 온보딩 상태 전환 등 이슈 해결
- **코드 리뷰** — Codex 교차 검증을 통한 구조 개선, 안전성 점검

<br/>

## Getting Started

```bash
# 1. 저장소 클론
git clone https://github.com/Sheep1sik/Microcosm.git
cd Microcosm

# 2. Tuist로 프로젝트 생성
tuist install
tuist generate

# 3. Xcode에서 빌드 및 실행
open Microcosm.xcworkspace
```

> **Note:** Firebase 설정 파일(`GoogleService-Info.plist`)과 API 키 설정(`Secrets.xcconfig`)은 보안상 저장소에 포함되어 있지 않습니다.
