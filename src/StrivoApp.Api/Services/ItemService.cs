using StrivoApp.Api.Data;
using StrivoApp.Api.Models;

namespace StrivoApp.Api.Services;

public class ItemService : IItemService
{
    private readonly IItemRepository _repository;

    public ItemService(IItemRepository repository)
    {
        _repository = repository;
    }

    public IEnumerable<Item> GetAllItems() => _repository.GetAll();

    public Item? GetItemById(int id) => _repository.GetById(id);

    public Item CreateItem(CreateItemRequest request) => _repository.Create(request);

    public Item? UpdateItem(int id, UpdateItemRequest request) => _repository.Update(id, request);
}
