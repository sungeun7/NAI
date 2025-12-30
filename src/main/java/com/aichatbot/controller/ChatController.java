package com.aichatbot.controller;

import com.aichatbot.model.ChatRequest;
import com.aichatbot.model.ChatResponse;
import com.aichatbot.service.AiService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpSession;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Controller
public class ChatController {

    @Autowired
    private AiService aiService;
    
    private final ExecutorService executorService = Executors.newFixedThreadPool(5);

    @GetMapping("/")
    public String index(Model model, HttpSession session) {
        if (session.getAttribute("messages") == null) {
            session.setAttribute("messages", new ArrayList<Map<String, String>>());
        }
        model.addAttribute("aiTypes", List.of(
            "Google Gemini (무료)"
        ));
        model.addAttribute("geminiModels", List.of(
            "gemini-pro",
            "gemini-1.5-flash",
            "gemini-1.5-pro"
        ));
        model.addAttribute("openaiModels", List.of(
            "gpt-3.5-turbo",
            "gpt-4",
            "gpt-4-turbo-preview"
        ));
        return "index";
    }

    @PostMapping("/chat")
    @ResponseBody
    public ResponseEntity<ChatResponse> chat(@RequestBody ChatRequest request, HttpSession session) {
        System.out.println("\n========== /chat 엔드포인트 호출 ==========");
        
        // 요청 검증
        if (request == null) {
            System.err.println("❌ 요청이 null입니다.");
            return ResponseEntity.ok(new ChatResponse("❌ 잘못된 요청입니다. 요청 본문이 비어있습니다.", false));
        }
        
        try {
            System.out.println("요청 받음 - AI 타입: " + (request.getAiType() != null ? request.getAiType() : "null"));
            System.out.println("프롬프트: " + (request.getPrompt() != null ? request.getPrompt().substring(0, Math.min(50, request.getPrompt().length())) + "..." : "null"));
            System.out.println("모델: " + (request.getModel() != null ? request.getModel() : "null"));
        } catch (Exception e) {
            System.err.println("❌ 요청 정보 출력 중 오류: " + e.getMessage());
        }
        
        // 프롬프트 검증
        if (request.getPrompt() == null || request.getPrompt().trim().isEmpty()) {
            System.err.println("❌ 프롬프트가 null이거나 비어있습니다.");
            return ResponseEntity.ok(new ChatResponse("❌ 메시지를 입력해주세요.", false));
        }
        
        List<Map<String, String>> messagesList = null;
        try {
            @SuppressWarnings("unchecked")
            List<Map<String, String>> temp = (List<Map<String, String>>) session.getAttribute("messages");
            messagesList = temp;
        } catch (Exception e) {
            System.err.println("❌ 세션에서 메시지 가져오기 실패: " + e.getMessage());
            messagesList = null;
        }
        
        if (messagesList == null) {
            messagesList = new ArrayList<>();
            try {
                session.setAttribute("messages", messagesList);
            } catch (Exception e) {
                System.err.println("❌ 세션에 메시지 설정 실패: " + e.getMessage());
            }
        }

        // 사용자 메시지 추가
        try {
            Map<String, String> userMessage = new HashMap<>();
            userMessage.put("role", "user");
            userMessage.put("content", request.getPrompt());
            messagesList.add(userMessage);
        } catch (Exception e) {
            System.err.println("❌ 사용자 메시지 추가 실패: " + e.getMessage());
        }
        
        // final 변수로 복사 (CompletableFuture에서 사용하기 위해)
        final List<Map<String, String>> messages = new ArrayList<>(messagesList);

        String response = null;
        Thread progressLogger = null;
        try {
            System.out.println("AI 서비스 호출 시작...");
            long startTime = System.currentTimeMillis();
            
            // 주기적으로 진행 상황 로그 출력
            progressLogger = new Thread(() -> {
                try {
                    int count = 0;
                    while (!Thread.currentThread().isInterrupted() && count < 3) {
                        Thread.sleep(20000); // 20초마다
                        long elapsed = System.currentTimeMillis() - startTime;
                        System.out.println("⏳ AI 서비스 처리 중... (" + (elapsed / 1000) + "초 경과)");
                        count++;
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            });
            progressLogger.setDaemon(true);
            progressLogger.start();
            
            try {
                // CompletableFuture를 사용하여 120초 타임아웃 강제 적용
                CompletableFuture<String> futureResponse = CompletableFuture.supplyAsync(() -> {
                    try {
                        System.out.println("CompletableFuture 내부에서 AI 서비스 호출 시작...");
                        String result = aiService.getResponse(
                            request.getAiType(),
                            request.getPrompt(),
                            messages,
                            request.getModel(),
                            request.getGeminiApiKey(),
                            request.getOpenaiApiKey(),
                            request.getTemperature()
                        );
                        System.out.println("CompletableFuture 내부에서 AI 서비스 호출 완료");
                        return result;
                    } catch (Throwable e) {
                        System.err.println("❌ AI 서비스에서 예외 발생: " + e.getClass().getName() + " - " + e.getMessage());
                        e.printStackTrace();
                        return "❌ AI 서비스 오류가 발생했습니다.\n\n" +
                               "오류: " + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()) + "\n\n" +
                               "💡 해결 방법:\n" +
                               "1. 🔄 페이지 새로고침 후 다시 시도\n" +
                               "2. 🌐 인터넷 연결 확인\n" +
                               "3. ⏰ 잠시 후 다시 시도";
                    }
                }, executorService).exceptionally(throwable -> {
                    System.err.println("❌ CompletableFuture에서 예외 발생: " + throwable.getClass().getName() + " - " + throwable.getMessage());
                    throwable.printStackTrace();
                    return "❌ 요청 처리 중 오류가 발생했습니다.\n\n" +
                           "오류: " + (throwable.getMessage() != null ? throwable.getMessage() : throwable.getClass().getSimpleName()) + "\n\n" +
                           "💡 해결 방법:\n" +
                           "1. 🔄 페이지 새로고침 후 다시 시도\n" +
                           "2. 🌐 인터넷 연결 확인\n" +
                           "3. ⏰ 잠시 후 다시 시도";
                });
                
                // 120초 타임아웃 적용 (모델 로딩 시간 확보)
                try {
                    response = futureResponse.get(120, TimeUnit.SECONDS);
                } catch (TimeoutException e) {
                    System.err.println("⏱️ AI 서비스 호출 타임아웃 (120초 초과)");
                    futureResponse.cancel(true);
                    // 타임아웃 시 기본 응답 반환 (오류 메시지 대신)
                    response = "⏱️ 응답 시간이 초과되었습니다.\n\n" +
                              "시도 시간: 120초\n\n" +
                              "모델 연결에 시간이 오래 걸리고 있습니다.\n" +
                              "기본 응답 모드로 전환합니다.\n\n" +
                              "💡 해결 방법:\n" +
                              "1. ⏰ 잠시 후 다시 시도 (모델 로딩 완료 대기)\n" +
                              "2. 🔄 페이지 새로고침\n" +
                              "3. 🌐 인터넷 연결 확인\n" +
                              "4. 서버 콘솔 로그 확인 (상세 오류 정보)";
                } catch (Exception e) {
                    System.err.println("❌ CompletableFuture에서 예외 발생: " + e.getClass().getName() + " - " + e.getMessage());
                    e.printStackTrace();
                    futureResponse.cancel(true);
                    response = "❌ 요청 처리 중 오류가 발생했습니다.\n\n" +
                              "오류: " + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()) + "\n\n" +
                              "💡 해결 방법:\n" +
                              "1. 🔄 페이지 새로고침 후 다시 시도\n" +
                              "2. 🌐 인터넷 연결 확인\n" +
                              "3. ⏰ 잠시 후 다시 시도";
                }
            } catch (Throwable serviceException) {
                System.err.println("❌ AI 서비스 호출 중 심각한 예외 발생:");
                System.err.println("예외 타입: " + serviceException.getClass().getName());
                System.err.println("예외 메시지: " + (serviceException.getMessage() != null ? serviceException.getMessage() : "메시지 없음"));
                serviceException.printStackTrace();
                
                response = "❌ AI 서비스 오류가 발생했습니다.\n\n" +
                          "오류: " + (serviceException.getMessage() != null ? serviceException.getMessage() : serviceException.getClass().getSimpleName()) + "\n\n" +
                          "💡 해결 방법:\n" +
                          "1. 🔄 페이지 새로고침 후 다시 시도\n" +
                          "2. 🌐 인터넷 연결 확인\n" +
                          "3. ⏰ 잠시 후 다시 시도";
            } finally {
                progressLogger.interrupt();
            }

            long elapsedTime = System.currentTimeMillis() - startTime;
            System.out.println("AI 서비스 응답 받음 (소요 시간: " + elapsedTime + "ms)");
            
            // 응답이 null이거나 비어있으면 오류 메시지 반환
            if (response == null || response.trim().isEmpty()) {
                System.err.println("⚠️ 응답이 null이거나 비어있음");
                response = "❌ AI 모델 연결에 실패했습니다.\n\n" +
                          "시도 시간: " + (elapsedTime / 1000) + "초\n\n" +
                          "💡 해결 방법:\n" +
                          "1. ⏰ 잠시 후 다시 시도\n" +
                          "2. 🔄 페이지 새로고침\n" +
                          "3. 🌐 인터넷 연결 확인";
            }
            
            System.out.println("응답 길이: " + (response != null ? response.length() : 0) + "자");
            if (response != null && response.length() > 0) {
                System.out.println("응답 앞부분: " + response.substring(0, Math.min(100, response.length())) + "...");
            }

            // AI 응답 추가
            Map<String, String> assistantMessage = new HashMap<>();
            assistantMessage.put("role", "assistant");
            assistantMessage.put("content", response);
            messages.add(assistantMessage);

            System.out.println("응답 전송 준비 완료");
            System.out.println("========== /chat 엔드포인트 응답 전송 ==========\n");
            
            return ResponseEntity.ok(new ChatResponse(response, true));
            
        } catch (Throwable e) {
            // 모든 예외를 잡아서 응답 보장
            System.err.println("\n❌ /chat 엔드포인트에서 심각한 예외 발생:");
            System.err.println("예외 타입: " + e.getClass().getName());
            System.err.println("예외 메시지: " + (e.getMessage() != null ? e.getMessage() : "메시지 없음"));
            e.printStackTrace();
            
            String errorMsg = "❌ 서버 오류가 발생했습니다.\n\n" +
                             "오류: " + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()) + "\n\n" +
                             "💡 해결 방법:\n" +
                             "1. 🔄 페이지 새로고침 후 다시 시도\n" +
                             "2. 🌐 인터넷 연결 확인\n" +
                             "3. ⏰ 잠시 후 다시 시도\n" +
                             "4. 서버 콘솔 로그 확인";
            
            // 응답을 반환하기 전에 모든 리소스 정리
            try {
                if (progressLogger != null && progressLogger.isAlive()) {
                    progressLogger.interrupt();
                }
            } catch (Exception ex) {
                System.err.println("progressLogger 중단 실패: " + ex.getMessage());
            }
            
            try {
                // messages가 null이 아닌 경우에만 추가
                if (messages != null) {
                    Map<String, String> errorMessage = new HashMap<>();
                    errorMessage.put("role", "assistant");
                    errorMessage.put("content", errorMsg);
                    messages.add(errorMessage);
                }
            } catch (Exception ex) {
                // 메시지 추가 실패 시 무시
                System.err.println("메시지 추가 실패: " + ex.getMessage());
            }
            
            System.out.println("에러 응답 전송: " + errorMsg);
            System.out.println("========== /chat 엔드포인트 에러 응답 전송 ==========\n");
            
            // 항상 응답을 반환하도록 보장
            try {
                return ResponseEntity.ok(new ChatResponse(errorMsg, false));
            } catch (Exception ex) {
                System.err.println("❌ ResponseEntity 생성 실패: " + ex.getMessage());
                ex.printStackTrace();
                // 최후의 수단: 간단한 응답 반환
                return ResponseEntity.status(500).body(new ChatResponse("❌ 서버 오류가 발생했습니다.", false));
            }
        }
    }

    @PostMapping("/clear")
    @ResponseBody
    public ResponseEntity<Map<String, String>> clear(HttpSession session) {
        session.setAttribute("messages", new ArrayList<Map<String, String>>());
        Map<String, String> response = new HashMap<>();
        response.put("status", "success");
        return ResponseEntity.ok(response);
    }

    @PostMapping("/shutdown")
    @ResponseBody
    public ResponseEntity<Map<String, String>> shutdown() {
        System.out.println("\n========== 서버 종료 요청 받음 ==========");
        System.out.println("브라우저 창이 닫혔습니다. 서버를 종료합니다...");
        
        Map<String, String> response = new HashMap<>();
        response.put("status", "shutting_down");
        response.put("message", "서버 종료 중...");
        
        // 별도 스레드에서 서버 종료 (응답을 먼저 보낸 후 종료)
        new Thread(() -> {
            try {
                Thread.sleep(500); // 응답 전송 대기
                System.out.println("서버 종료 실행 중...");
                System.exit(0);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                System.exit(0);
            }
        }).start();
        
        return ResponseEntity.ok(response);
    }
}

