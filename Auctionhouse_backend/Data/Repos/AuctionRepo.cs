using Auctionhouse_backend.Data.Entities;
using Auctionhouse_backend.Data.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Auctionhouse_backend.Data.Repos
{
    public class AuctionRepo : IAuctionRepo
    {
        private readonly AppDbContext _context;

        public AuctionRepo(AppDbContext context)
        {
            _context = context;
        }
        public async Task<Auction> Create(Auction auction)
        {
            _context.Auctions.Add(auction);
            await _context.SaveChangesAsync();
            return auction;
        }

        public async Task<bool> Delete(int id)
        {
            var auction = await _context.Auctions.FindAsync(id);
            if (auction == null)
            {
                return false;
            }

            _context.Auctions.Remove(auction);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<List<Auction>> GetAuctionByUser(int userId)
        {
            return await _context.Auctions
                .Include(a => a.User)
                .Where(a => a.UserId == userId)
                .OrderByDescending(a => a.EndDate)
                .ToListAsync();
        }

        public async Task<Auction?> GetById(int id)
        {
            return await _context.Auctions
                .Include(a => a.User)
                .Include(a => a.Bids)
                  .ThenInclude(b => b.User)
                .FirstOrDefaultAsync(a => a.Id == id);
        }

        public async Task<List<Auction>> GetOpenAuctions()
        {
            return await _context.Auctions
                .Include(a => a.User)
                .Include(a => a.Bids)
                .Where(a => a.EndDate > DateTime.UtcNow && a.IsActive)
                .OrderByDescending(a => a.EndDate)
                .ToListAsync();
        }

        public async Task<List<Auction>> SearchByTitle(string title)
        {
            return await _context.Auctions
                .Include(a => a.User)
                .Include(a => a.Bids)
                .Where(a => a.Title.Contains(title) && a.EndDate > DateTime.UtcNow && a.IsActive)
                .OrderByDescending(a => a.EndDate)
                .ToListAsync();
        }

        public async Task<Auction> Update(Auction auction)
        {
            _context.Auctions.Update(auction);
            await _context.SaveChangesAsync();
            return auction;
        }

        public async Task<bool> UserOwnsAuction(int auctionId, int userId)
        {
            return await _context.Auctions
              .AnyAsync(a => a.Id == auctionId && a.UserId == userId);
        }

        public async Task<List<Auction>> GetAllAuctions()
        {
            return await _context.Auctions
                .Include(a => a.User)
                .Include(a => a.Bids)
                .OrderByDescending(a => a.EndDate)
                .ToListAsync();
        }

        public async Task<List<Auction>> SearchAllAuctions(string title)
        {
            return await _context.Auctions
                .Include(a => a.User)
                .Include(a => a.Bids)
                .Where(a => a.Title.Contains(title)
                    && a.IsActive)
                .OrderByDescending(a => a.EndDate)
                .ToListAsync();
        }

    }

}
