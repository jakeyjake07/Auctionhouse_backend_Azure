using Auctionhouse_backend.Data.Entities;

namespace Auctionhouse_backend.Data.Interfaces
{
    public interface IUserRepo
    {
        Task<User?> GetById(int id);
        Task<User?> GetByUsername(string username);
        Task<User?> GetByEmail(string email);
        Task<bool> UsernameExists(string username);
        Task<bool> EmailExists(string email);
        Task<User> Create(User user);
        Task<User> Update(User user);
        Task<bool> Delete(int id);

        Task<List<User>> GetAllUsers();
        Task<bool> ToggleUserActive(int id, bool isActive);
    }
}
