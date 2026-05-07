using Auctionhouse_backend.DTOs.Bid;

namespace Auctionhouse_backend.Core.Interfaces
{
    public interface IBidService
    {
        Task<BidResponseDto?> PlaceBid(int userId, PlaceBidDto dto);
        Task<List<BidResponseDto>> GetBidsForAuction(int auctionId);
        Task<BidResponseDto?> GetHighestBidForAuction(int auctionId);
        Task<BidResponseDto?> GetBidById(int bidId);
        Task<bool> DeleteBid(int bidId, int userId);
    }
}
