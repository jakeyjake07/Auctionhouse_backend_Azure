using Auctionhouse_backend.Data.Entities;
using Auctionhouse_backend.Data.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Auctionhouse_backend.Data.Repos
{
    public class BidRepo : IBidRepo
    {
        private readonly AppDbContext _context;

        public BidRepo(AppDbContext context)
        {
            _context = context;
        }

        public async Task<Bid> Create(Bid bid)
        {
            bid.BidDate = DateTime.UtcNow;
            _context.Bids.Add(bid);
            await _context.SaveChangesAsync();
            return bid;
        }

        public async Task<bool> Delete(int id)
        {
            var bid = await _context.Bids.FindAsync(id);

            if (bid == null)
            {
                return false;
            }

            _context.Bids.Remove(bid);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<List<Bid>> GetBidsForAuction(int auctionId)
        {
            return await _context.Bids
               .Include(b => b.User)
               .Where(b => b.AuctionId == auctionId)
               .OrderByDescending(b => b.Amount)
               .ToListAsync();
        }

        public async Task<Bid?> GetById(int id)
        {
            return await _context.Bids
                .Include(b => b.User)
                .Include(b => b.Auction)
                .FirstOrDefaultAsync(b => b.Id == id);
        }

        public async Task<decimal> GetHighestBidForAuction(int auctionId)
        {
            var highestBid = await _context.Bids
                .Where(b => b.AuctionId == auctionId)
                .OrderByDescending(b => b.Amount)
                .FirstOrDefaultAsync();

            return highestBid?.Amount ?? 0;
        }

        public async Task<bool> IsHighestBidder(int bidId, int userId)
        {
            var bid = await _context.Bids.FindAsync(bidId);
            if (bid == null)
            {
                return false;
            }

            var highestBid = await GetHighestBidForAuction(bid.AuctionId);

            return bid.Amount == highestBid && bid.UserId == userId;
        }
    }
}
