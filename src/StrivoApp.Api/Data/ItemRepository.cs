using StrivoApp.Api.Models;

namespace StrivoApp.Api.Data;

public class ItemRepository : IItemRepository
{
    private readonly List<Item> _items = new()
    {
        new Item { Id = 1, Name = "First Item",  Description = "Description for first item",  CreatedAt = new DateTime(2024, 1, 10) },
        new Item { Id = 2, Name = "Second Item", Description = "Description for second item", CreatedAt = new DateTime(2024, 2, 15) },
        new Item { Id = 3, Name = "Third Item",  Description = "Description for third item",  CreatedAt = new DateTime(2024, 3, 20) },
    };

    private readonly object _lock = new();
    private int _nextId = 4;

    public IEnumerable<Item> GetAll()
    {
        lock (_lock)
        {
            return _items.ToList();
        }
    }

    public Item? GetById(int id)
    {
        lock (_lock)
        {
            return _items.FirstOrDefault(i => i.Id == id);
        }
    }

    public Item Create(CreateItemRequest request)
    {
        lock (_lock)
        {
            var item = new Item
            {
                Id          = _nextId++,
                Name        = request.Name,
                Description = request.Description,
                CreatedAt   = DateTime.UtcNow,
            };

            _items.Add(item);
            return item;
        }
    }

    public Item? Update(int id, UpdateItemRequest request)
    {
        lock (_lock)
        {
            var item = _items.FirstOrDefault(i => i.Id == id);
            if (item is null)
                return null;

            item.Name        = request.Name;
            item.Description = request.Description;
            return item;
        }
    }
}
