package client.controllers;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import client.model.Item;
import client.service.ItemService;

@RestController
public class ClientController {

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    private ItemService itemService;

    @Value("${HELLO_SERVICE_URL}")
    private String helloServiceUrl;

    @GetMapping("/health")
    public String health() {
        return "OK";
    }

    // ========== MESSAGING ENDPOINTS (Original) ==========
    
    @PostMapping("/send-to-hello")
    public Map<String, Object> sendMessageToHello(@RequestBody Map<String, String> request) {
        String message = request.getOrDefault("message", "Hello from ClientService!");
        
        try {
            Map<String, Object> response = restTemplate.postForObject(
                helloServiceUrl + "/hello/receive-message",
                Map.of("message", message, "from", "ClientService"),
                Map.class
            );
            
            return Map.of(
                "status", "success",
                "sentTo", "HelloService",
                "yourMessage", message,
                "helloResponse", response,
                "timestamp", System.currentTimeMillis()
            );
        } catch (Exception e) {
            return Map.of(
                "status", "error",
                "message", "Failed to reach HelloService: " + e.getMessage(),
                "timestamp", System.currentTimeMillis()
            );
        }
    }

    @PostMapping("/receive-message")
    public Map<String, Object> receiveMessage(@RequestBody Map<String, String> request) {
        String message = request.getOrDefault("message", "");
        String from = request.getOrDefault("from", "Unknown");
        
        return Map.of(
            "status", "received",
            "message", "ClientService received your message!",
            "yourMessage", message,
            "receivedFrom", from,
            "response", "Thanks for the message, " + from + "! 👋",
            "timestamp", System.currentTimeMillis()
        );
    }

    // ========== ITEM MANAGEMENT ENDPOINTS (New) ==========

    @PostMapping("/api/items")
    public ResponseEntity<Map<String, Object>> createItem(@RequestBody Item item) {
        try {
            Item createdItem = itemService.createItem(item);
            return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                "status", "success",
                "message", "Item created successfully in OrderService",
                "item", createdItem
            ));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                "status", "error",
                "message", "Failed to create item: " + e.getMessage()
            ));
        }
    }

    @GetMapping("/api/items")
    public ResponseEntity<Map<String, Object>> getAllItems() {
        List<Item> items = itemService.getAllItems();
        return ResponseEntity.ok(Map.of(
            "status", "success",
            "totalItems", items.size(),
            "items", items
        ));
    }

    @GetMapping("/api/items/{id}")
    public ResponseEntity<Map<String, Object>> getItemById(@PathVariable Long id) {
        Item item = itemService.getItemById(id);
        if (item != null) {
            return ResponseEntity.ok(Map.of(
                "status", "success",
                "item", item
            ));
        } else {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                "status", "error",
                "message", "Item not found with id: " + id
            ));
        }
    }
}
