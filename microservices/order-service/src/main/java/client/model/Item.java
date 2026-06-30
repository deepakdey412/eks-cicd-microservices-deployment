package client.model;

public class Item {
    private Long id;
    private String name;
    private String description;
    private Double price;
    private String createdBy;
    private Long timestamp;

    public Item() {
    }

    public Item(Long id, String name, String description, Double price, String createdBy) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.price = price;
        this.createdBy = createdBy;
        this.timestamp = System.currentTimeMillis();
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Double getPrice() {
        return price;
    }

    public void setPrice(Double price) {
        this.price = price;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public Long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(Long timestamp) {
        this.timestamp = timestamp;
    }
}
