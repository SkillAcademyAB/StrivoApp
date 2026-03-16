using System.ComponentModel.DataAnnotations;

namespace StrivoApp.Api.Models;

public class UpdateItemRequest
{
    [Required]
    [StringLength(200, MinimumLength = 1)]
    public string Name { get; set; } = string.Empty;

    [StringLength(1000)]
    public string Description { get; set; } = string.Empty;
}
