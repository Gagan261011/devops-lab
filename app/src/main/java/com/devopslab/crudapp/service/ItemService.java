package com.devopslab.crudapp.service;

import com.devopslab.crudapp.model.Item;
import com.devopslab.crudapp.repository.ItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class ItemService {
    
    @Autowired
    private ItemRepository itemRepository;
    
    public List<Item> getAllItems() {
        return itemRepository.findAll();
    }
    
    public Optional<Item> getItemById(Long id) {
        return itemRepository.findById(id);
    }
    
    public Item createItem(Item item) {
        return itemRepository.save(item);
    }
    
    public Item updateItem(Long id, Item itemDetails) {
        Item item = itemRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Item not found with id: " + id));
        
        item.setName(itemDetails.getName());
        item.setDescription(itemDetails.getDescription());
        item.setPrice(itemDetails.getPrice());
        item.setQuantity(itemDetails.getQuantity());
        
        return itemRepository.save(item);
    }
    
    public void deleteItem(Long id) {
        Item item = itemRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Item not found with id: " + id));
        itemRepository.delete(item);
    }
    
    public List<Item> searchItemsByName(String name) {
        return itemRepository.findByNameContaining(name);
    }
    
    public List<Item> getItemsByMaxPrice(Double maxPrice) {
        return itemRepository.findByPriceLessThan(maxPrice);
    }
}
