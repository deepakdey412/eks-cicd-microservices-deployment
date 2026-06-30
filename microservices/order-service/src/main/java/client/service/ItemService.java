package client.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.stereotype.Service;

import client.model.Item;

@Service
public class ItemService {
    
    private final Map<Long, Item> itemStore = new ConcurrentHashMap<>();
    private final AtomicLong idCounter = new AtomicLong(1);

    public Item createItem(Item item) {
        Long id = idCounter.getAndIncrement();
        item.setId(id);
        item.setTimestamp(System.currentTimeMillis());
        itemStore.put(id, item);
        return item;
    }

    public List<Item> getAllItems() {
        return new ArrayList<>(itemStore.values());
    }

    public Item getItemById(Long id) {
        return itemStore.get(id);
    }

    public boolean deleteItem(Long id) {
        return itemStore.remove(id) != null;
    }

    public int getItemCount() {
        return itemStore.size();
    }
}
