package helloservice.controllers;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

@RestController
@RequestMapping("/hello")
public class HelloController {

    @Value("${spring.application.name}")
    private String appName;

    @Autowired
    private RestTemplate restTemplate;

    @Value("${CLIENT_SERVICE_URL}")
    private String clientServiceUrl;

    @GetMapping
    public String getHello() {
        return String.format("🎉 Hello from %s! Running on EKS 🚀", appName);
    }

    @GetMapping("/health")
    public String health() {
        return "OK";
    }

    // ========== MESSAGING ENDPOINTS (Original) ==========

    @PostMapping("/send-to-client")
    public Map<String, Object> sendMessageToClient(@RequestBody Map<String, String> request) {
        String message = request.getOrDefault("message", "Hello from HelloService!");
        
        try {
            Map<String, Object> response = restTemplate.postForObject(
                clientServiceUrl + "/receive-message",
                Map.of("message", message, "from", "HelloService"),
                Map.class
            );
            
            return Map.of(
                "status", "success",
                "sentTo", "ClientService",
                "yourMessage", message,
                "clientResponse", response,
                "timestamp", System.currentTimeMillis()
            );
        } catch (Exception e) {
            return Map.of(
                "status", "error",
                "message", "Failed to reach ClientService: " + e.getMessage(),
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
            "message", "HelloService received your message!",
            "yourMessage", message,
            "receivedFrom", from,
            "response", "Thanks for the message, " + from + "! 🎉",
            "timestamp", System.currentTimeMillis()
        );
    }

    // ========== ITEM MANAGEMENT ENDPOINTS (New) ==========

    @PostMapping("/create-item")
    public ResponseEntity<Map<String, Object>> createItem(@RequestBody Map<String, Object> itemData) {
        try {
            String name = (String) itemData.getOrDefault("name", "Unknown Product");
            String description = (String) itemData.getOrDefault("description", "No description");
            Double price = itemData.containsKey("price") ? 
                Double.valueOf(itemData.get("price").toString()) : 0.0;

            Map<String, Object> item = Map.of(
                "name", name,
                "description", description,
                "price", price,
                "createdBy", "ProductService (HelloService)"
            );

            Map<String, Object> response = restTemplate.postForObject(
                clientServiceUrl + "/api/items",
                item,
                Map.class
            );

            return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                "status", "success",
                "message", "Item created successfully in OrderService via ProductService",
                "productServiceAction", "Sent create request to OrderService",
                "orderServiceResponse", response,
                "timestamp", System.currentTimeMillis()
            ));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                "status", "error",
                "message", "Failed to create item in OrderService: " + e.getMessage(),
                "timestamp", System.currentTimeMillis()
            ));
        }
    }

    @GetMapping("/items")
    public ResponseEntity<Map<String, Object>> getAllItems() {
        try {
            Map<String, Object> response = restTemplate.getForObject(
                clientServiceUrl + "/api/items",
                Map.class
            );

            return ResponseEntity.ok(Map.of(
                "status", "success",
                "message", "Items fetched from OrderService via ProductService",
                "orderServiceResponse", response,
                "timestamp", System.currentTimeMillis()
            ));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                "status", "error",
                "message", "Failed to fetch items from OrderService: " + e.getMessage(),
                "timestamp", System.currentTimeMillis()
            ));
        }
    }

    @GetMapping("/items/{id}")
    public ResponseEntity<Map<String, Object>> getItemById(@PathVariable Long id) {
        try {
            Map<String, Object> response = restTemplate.getForObject(
                clientServiceUrl + "/api/items/" + id,
                Map.class
            );

            return ResponseEntity.ok(Map.of(
                "status", "success",
                "message", "Item fetched from OrderService via ProductService",
                "orderServiceResponse", response,
                "timestamp", System.currentTimeMillis()
            ));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                "status", "error",
                "message", "Failed to fetch item from OrderService: " + e.getMessage(),
                "timestamp", System.currentTimeMillis()
            ));
        }
    }
}
