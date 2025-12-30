package com.aichatbot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.beans.factory.annotation.Autowired;

import java.awt.Desktop;
import java.net.URI;
import java.util.concurrent.CompletableFuture;

@SpringBootApplication
public class AiChatbotApplication {
    
    @Autowired
    private Environment environment;
    
    public static void main(String[] args) {
        SpringApplication.run(AiChatbotApplication.class, args);
    }
    
    @EventListener(ApplicationReadyEvent.class)
    public void openBrowser() {
        // 비동기로 실행하여 서버 시작을 방해하지 않음
        CompletableFuture.runAsync(() -> {
            try {
                // 서버가 완전히 준비될 때까지 잠시 대기
                Thread.sleep(1000);
                
                // 서버 포트 가져오기 (기본값: 8080)
                String port = environment.getProperty("server.port", "8080");
                String url = "http://localhost:" + port;
                
                boolean opened = false;
                
                // 방법 1: Desktop API 시도
                try {
                    if (Desktop.isDesktopSupported() && Desktop.getDesktop().isSupported(Desktop.Action.BROWSE)) {
                        Desktop.getDesktop().browse(new URI(url));
                        opened = true;
                        System.out.println("브라우저가 자동으로 열렸습니다: " + url);
                    }
                } catch (Exception e) {
                    // Desktop API 실패 시 다음 방법 시도
                }
                
                // 방법 2: Windows 명령어로 브라우저 열기
                if (!opened) {
                    String os = System.getProperty("os.name").toLowerCase();
                    if (os.contains("win")) {
                        // Windows: 여러 방법 시도
                        try {
                            // 방법 2-1: start 명령어
                            Runtime.getRuntime().exec("cmd /c start " + url);
                            opened = true;
                            System.out.println("브라우저가 자동으로 열렸습니다: " + url);
                        } catch (Exception e) {
                            try {
                                // 방법 2-2: PowerShell 사용
                                Runtime.getRuntime().exec("powershell -Command Start-Process '" + url + "'");
                                opened = true;
                                System.out.println("브라우저가 자동으로 열렸습니다: " + url);
                            } catch (Exception e2) {
                                // 방법 2-3: rundll32 사용
                                try {
                                    Runtime.getRuntime().exec("rundll32 url.dll,FileProtocolHandler " + url);
                                    opened = true;
                                    System.out.println("브라우저가 자동으로 열렸습니다: " + url);
                                } catch (Exception e3) {
                                    // 모든 방법 실패
                                }
                            }
                        }
                    } else if (os.contains("mac")) {
                        // macOS
                        Runtime.getRuntime().exec("open " + url);
                        opened = true;
                        System.out.println("브라우저가 자동으로 열렸습니다: " + url);
                    } else if (os.contains("nix") || os.contains("nux")) {
                        // Linux
                        Runtime.getRuntime().exec("xdg-open " + url);
                        opened = true;
                        System.out.println("브라우저가 자동으로 열렸습니다: " + url);
                    }
                }
                
                if (!opened) {
                    System.out.println("브라우저를 자동으로 열 수 없습니다. 수동으로 접속하세요: " + url);
                }
                
            } catch (Exception e) {
                // 브라우저 열기 실패 시 무시 (서버는 정상 작동)
                System.out.println("브라우저 자동 실행 시도 중 오류 발생 (무시 가능): " + e.getMessage());
            }
        });
    }
}

