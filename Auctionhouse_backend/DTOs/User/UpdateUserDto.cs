using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.DTOs.User
{
    public class UpdateUserDto
    {

        [EmailAddress]
        public string? Email { get; set; }
    }
}
