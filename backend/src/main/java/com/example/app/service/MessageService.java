package com.example.app.service;

import com.example.app.model.Message;
import com.example.app.repository.MessageRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class MessageService {

    private static final Logger logger = LoggerFactory.getLogger(MessageService.class);

    @Autowired
    private MessageRepository messageRepository;

    @Cacheable(value = "messages")
    public List<Message> getAllMessages() {
        try {
            logger.info("Fetching all messages from database");
            List<Message> messages = messageRepository.findAll();
            logger.info("Found {} messages", messages.size());
            return messages;
        } catch (Exception e) {
            logger.error("Error fetching messages: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to fetch messages: " + e.getMessage(), e);
        }
    }

    @Transactional
    @CacheEvict(value = "messages", allEntries = true)
    public Message saveMessage(Message message) {
        try {
            logger.info("Saving message: {}", message.getContent());
            Message saved = messageRepository.save(message);
            logger.info("Message saved successfully with ID: {}", saved.getId());
            return saved;
        } catch (Exception e) {
            logger.error("Error saving message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to save message: " + e.getMessage(), e);
        }
    }
}


