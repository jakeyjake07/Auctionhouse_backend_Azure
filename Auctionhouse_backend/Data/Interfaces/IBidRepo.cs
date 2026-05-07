using Auctionhouse_backend.Data.Entities;

namespace Auctionhouse_backend.Data.Interfaces
{
    public interface IBidRepo
    {
        Task<Bid?> GetById(int id);
        Task<List<Bid>> GetBidsForAuction(int auctionId);
        Task<decimal> GetHighestBidForAuction(int auctionId);
        Task<Bid> Create(Bid bid);
        Task<bool> Delete(int id);
        Task<bool> IsHighestBidder(int bidId, int userId);
    }
}
