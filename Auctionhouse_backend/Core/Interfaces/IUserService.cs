using Auctionhouse_backend.DTOs.User;

namespace Auctionhouse_backend.Core.Interfaces
{
    public interface IUserService
    {
        Task<LoginResponseDto?> Register(RegisterDto registerDto);
        Task<LoginResponseDto?> Login(LoginDto loginDto);
        Task<UserResponseDto?> GetUserById(int id);
        Task<UserResponseDto?> UpdateUser(int id, UpdateUserDto updateUserDto);
        Task<bool> DeleteUser(int id);

        Task<bool> ChangePassword(int userId, string currentPassword, string newPassword);
        Task<bool> ToggleUserActive(int userId, int adminId);

        Task<List<UserResponseDto>> GetAllUsers();
    }
}
