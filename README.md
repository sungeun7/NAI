# AI 챗봇 프로그램 (Java 버전)

Spring Boot를 사용한 Java 기반 AI 챗봇 프로그램입니다. **API 키 없이 무료로 사용**할 수 있습니다!

## 기능

- 🤖 간단한 챗봇 (로컬)
- 🌐 Google Gemini (무료)
- 💬 OpenAI ChatGPT (무료)
- 💬 실시간 채팅 인터페이스
- 🔄 대화 기록 유지
- ⚙️ 모델 및 온도 설정 가능
- 🗑️ 대화 기록 초기화
- ✅ **완전 무료**

## 빠른 시작

### 실행 방법

**`실행.bat`** 파일을 더블클릭하세요!
- Java 자동 감지
- Maven 자동 빌드
- 프로그램 자동 실행

또는 명령 프롬프트에서:
```bash
mvn spring-boot:run
```

브라우저에서 `http://localhost:8080` 접속

## 사용 방법

### 방법 1: 간단한 챗봇 (추천 - 즉시 사용 가능)

1. 프로그램 실행: `실행.bat`
2. 사이드바에서 "간단한 챗봇 (로컬) - 추천" 선택 (기본값)
3. 바로 채팅 시작!

**장점**: 완전 무료, 인터넷 불필요, 프라이버시 보호

### 방법 2: Google Gemini 사용

1. [Google AI Studio](https://aistudio.google.com/app/apikey)에서 무료 API 키 발급
2. 프로그램 실행
3. 사이드바에서 "Google Gemini (무료)" 선택
4. API 키 입력
5. 채팅 시작!

### 방법 3: OpenAI ChatGPT 사용

1. [OpenAI Platform](https://platform.openai.com/api-keys)에서 계정 생성
2. API 키 발급 (신규 가입 시 무료 크레딧 제공)
3. 사이드바에서 "OpenAI ChatGPT (무료)" 선택
4. API 키 입력
5. 채팅 시작!

## 파일 설명

- **`pom.xml`** - Maven 프로젝트 설정
- **`src/main/java/`** - Java 소스 코드
- **`src/main/resources/templates/index.html`** - 웹 인터페이스
- **`실행.bat`** - 프로그램 실행 스크립트
- **`README_Java.md`** - 상세 사용 설명서

## 요구사항

- Java 17 이상
- Maven 3.6 이상
- (Gemini/ChatGPT 사용 시) 인터넷 연결

## 문제 해결

### Java를 찾을 수 없을 때

1. Java 17 이상 설치: https://www.oracle.com/java/technologies/downloads/
2. 설치 시 JAVA_HOME 환경 변수 설정
3. 컴퓨터 재시작

### Maven을 찾을 수 없을 때

1. Maven 설치: https://maven.apache.org/download.cgi
2. 또는 Maven Wrapper 사용

### 포트 8080이 이미 사용 중입니다

`src/main/resources/application.properties`에서 `server.port`를 변경하세요

## 주의사항

- Gemini API 사용 시 첫 사용 시 모델 로딩으로 인해 시간이 걸릴 수 있습니다
- OpenAI API 사용 시 비용이 발생할 수 있습니다 (무료 크레딧 사용 후)
