using StrivoApp.Api.Models;

namespace StrivoApp.Api.Data;

public interface IItemRepository
{
    IEnumerable<Item> GetAll();
    Item? GetById(int id);
    Item Create(CreateItemRequest request);
    Item? Update(int id, UpdateItemRequest request);
}
