using StrivoApp.Api.Models;

namespace StrivoApp.Api.Services;

public interface IItemService
{
    IEnumerable<Item> GetAllItems();
    Item? GetItemById(int id);
    Item CreateItem(CreateItemRequest request);
    Item? UpdateItem(int id, UpdateItemRequest request);
}
