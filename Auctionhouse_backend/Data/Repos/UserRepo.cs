using Auctionhouse_backend.Data.Entities;
using Auctionhouse_backend.Data.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Auctionhouse_backend.Data.Repos
{
    public class UserRepo : IUserRepo
    {
        private readonly AppDbContext _context;

        public UserRepo(AppDbContext context)
        {
            _context = context;
        }




        public async Task<User?> GetById(int id)
        {
            return await _context.Users.FindAsync(id);
        }


        public async Task<bool> UsernameExists(string username)
        {
            return await _context.Users.AnyAsync(u => u.Username == username);
        }
        public async Task<bool> EmailExists(string email)
        {
            return await _context.Users.AnyAsync(u => u.Email == email);
        }

        public async Task<User> Create(User user)
        {
            _context.Users.Add(user);
            await _context.SaveChangesAsync();
            return user;
        }
        public async Task<User> Update(User user)
        {
            _context.Users.Update(user);
            await _context.SaveChangesAsync();
            return user;
        }
        public async Task<bool> Delete(int id)
        {
            var user = await GetById(id);
            if (user == null)
            {
                return false;
            }

            _context.Users.Remove(user);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<User?> GetByUsername(string username)
        {
            return await _context.Users.FirstOrDefaultAsync(u => u.Username == username);
        }

        public async Task<List<User>> GetAllUsers()
        {
            return await _context.Users.ToListAsync();
        }

        public async Task<bool> ToggleUserActive(int id, bool isActive)
        {
            var user = await GetById(id);
            if (user == null)
            {
                return false;
            }

            user.IsActive = isActive;
            await _context.SaveChangesAsync();
            return true;
        }


        public async Task<User?> GetByEmail(string email)
        {
            return await _context.Users
                .FirstOrDefaultAsync(u => u.Email == email);
        }
    }
}
