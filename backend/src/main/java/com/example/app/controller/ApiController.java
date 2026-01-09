package com.example.app.controller;

import com.example.app.model.Message;
import com.example.app.service.MessageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class ApiController {

    private static final Logger logger = LoggerFactory.getLogger(ApiController.class);

    @Autowired
    private MessageService messageService;

    @GetMapping("/messages")
    public ResponseEntity<?> getMessages() {
        try {
            logger.info("GET /api/messages - Fetching messages");
            List<Message> messages = messageService.getAllMessages();
            logger.info("GET /api/messages - Success, found {} messages", messages.size());
            return ResponseEntity.ok(messages);
        } catch (Exception e) {
            logger.error("GET /api/messages - Error: {}", e.getMessage(), e);
            Map<String, String> error = new HashMap<>();
            error.put("error", "Failed to fetch messages");
            error.put("message", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
        }
    }

    @PostMapping("/messages")
    public ResponseEntity<?> createMessage(@RequestBody Message message) {
        try {
            logger.info("POST /api/messages - Creating message: {}", message.getContent());
            if (message.getContent() == null || message.getContent().trim().isEmpty()) {
                Map<String, String> error = new HashMap<>();
                error.put("error", "Message content cannot be empty");
                return ResponseEntity.badRequest().body(error);
            }
            Message saved = messageService.saveMessage(message);
            logger.info("POST /api/messages - Success, message saved with ID: {}", saved.getId());
            return ResponseEntity.ok(saved);
        } catch (Exception e) {
            logger.error("POST /api/messages - Error: {}", e.getMessage(), e);
            Map<String, String> error = new HashMap<>();
            error.put("error", "Failed to create message");
            error.put("message", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
        }
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "OK");
        status.put("timestamp", String.valueOf(System.currentTimeMillis()));
        return ResponseEntity.ok(status);
    }

    @GetMapping("/health/db")
    public ResponseEntity<Map<String, Object>> healthDb() {
        Map<String, Object> status = new HashMap<>();
        try {
            // 尝试查询数据库
            long count = messageService.getAllMessages().size();
            status.put("status", "OK");
            status.put("database", "connected");
            status.put("message_count", count);
        } catch (Exception e) {
            logger.error("Database health check failed: {}", e.getMessage(), e);
            status.put("status", "ERROR");
            status.put("database", "disconnected");
            status.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(status);
        }
        return ResponseEntity.ok(status);
    }
}


