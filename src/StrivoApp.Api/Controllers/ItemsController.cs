using Microsoft.AspNetCore.Mvc;
using StrivoApp.Api.Models;
using StrivoApp.Api.Services;

namespace StrivoApp.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ItemsController : ControllerBase
{
    private readonly IItemService _service;

    public ItemsController(IItemService service)
    {
        _service = service;
    }

    /// <summary>Returns all items.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Item>), StatusCodes.Status200OK)]
    public IActionResult GetAll()
    {
        var items = _service.GetAllItems();
        return Ok(items);
    }

    /// <summary>Returns a single item by its ID.</summary>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(Item), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public IActionResult GetById(int id)
    {
        var item = _service.GetItemById(id);
        if (item is null)
            return NotFound();

        return Ok(item);
    }

    /// <summary>Creates a new item.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(Item), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public IActionResult Create([FromBody] CreateItemRequest request)
    {
        var item = _service.CreateItem(request);
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item);
    }

    /// <summary>Updates an existing item.</summary>
    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(Item), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public IActionResult Update(int id, [FromBody] UpdateItemRequest request)
    {
        var item = _service.UpdateItem(id, request);
        if (item is null)
            return NotFound();

        return Ok(item);
    }
}
