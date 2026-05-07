using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.DTOs.User
{
    public class ChangePasswordDto
    {
        [Required]
        public string CurrentPassword { get; set; } = string.Empty;

        [Required]
        [MinLength(3)]
        public string NewPassword { get; set; } = string.Empty;
    }
}
