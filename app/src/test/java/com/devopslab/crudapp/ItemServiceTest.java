package com.devopslab.crudapp;

import com.devopslab.crudapp.model.Item;
import com.devopslab.crudapp.repository.ItemRepository;
import com.devopslab.crudapp.service.ItemService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class ItemServiceTest {
    
    @Autowired
    private ItemService itemService;
    
    @Autowired
    private ItemRepository itemRepository;
    
    @BeforeEach
    public void setUp() {
        itemRepository.deleteAll();
    }
    
    @Test
    public void testCreateItem() {
        Item item = new Item(null, "Test Item", "Test Description", 10.0, 5);
        Item created = itemService.createItem(item);
        
        assertNotNull(created.getId());
        assertEquals("Test Item", created.getName());
        assertEquals(10.0, created.getPrice());
    }
    
    @Test
    public void testGetAllItems() {
        Item item1 = new Item(null, "Item 1", "Description 1", 10.0, 5);
        Item item2 = new Item(null, "Item 2", "Description 2", 20.0, 10);
        
        itemService.createItem(item1);
        itemService.createItem(item2);
        
        List<Item> items = itemService.getAllItems();
        assertEquals(2, items.size());
    }
    
    @Test
    public void testGetItemById() {
        Item item = new Item(null, "Test Item", "Test Description", 10.0, 5);
        Item created = itemService.createItem(item);
        
        Optional<Item> found = itemService.getItemById(created.getId());
        assertTrue(found.isPresent());
        assertEquals("Test Item", found.get().getName());
    }
    
    @Test
    public void testUpdateItem() {
        Item item = new Item(null, "Original", "Original Description", 10.0, 5);
        Item created = itemService.createItem(item);
        
        Item updates = new Item(null, "Updated", "Updated Description", 15.0, 10);
        Item updated = itemService.updateItem(created.getId(), updates);
        
        assertEquals("Updated", updated.getName());
        assertEquals(15.0, updated.getPrice());
    }
    
    @Test
    public void testDeleteItem() {
        Item item = new Item(null, "To Delete", "Will be deleted", 10.0, 5);
        Item created = itemService.createItem(item);
        
        itemService.deleteItem(created.getId());
        
        Optional<Item> found = itemService.getItemById(created.getId());
        assertFalse(found.isPresent());
    }
    
    @Test
    public void testSearchItemsByName() {
        Item item1 = new Item(null, "Apple", "Red Apple", 1.0, 100);
        Item item2 = new Item(null, "Banana", "Yellow Banana", 0.5, 200);
        Item item3 = new Item(null, "Orange", "Orange Fruit", 0.75, 150);
        
        itemService.createItem(item1);
        itemService.createItem(item2);
        itemService.createItem(item3);
        
        List<Item> found = itemService.searchItemsByName("an");
        assertEquals(2, found.size()); // Should find Banana and Orange
    }
}
