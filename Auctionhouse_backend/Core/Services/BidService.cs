using Auctionhouse_backend.Core.Interfaces;
using Auctionhouse_backend.Data.Entities;
using Auctionhouse_backend.Data.Interfaces;
using Auctionhouse_backend.DTOs.Bid;

namespace Auctionhouse_backend.Core.Services
{
    public class BidService : IBidService
    {

        private readonly IBidRepo _bidRepo;
        private readonly IAuctionRepo _auctionRepo;
        private readonly IUserRepo _userRepo;

        public BidService(IBidRepo bidRepo, IAuctionRepo auctionRepo, IUserRepo userRepo)
        {
            _bidRepo = bidRepo;
            _auctionRepo = auctionRepo;
            _userRepo = userRepo;
        }
        private BidResponseDto MapToDto(Bid bid)
        {
            return new BidResponseDto
            {
                Id = bid.Id,
                Amount = bid.Amount,
                BidDate = bid.BidDate,
                UserId = bid.UserId,
                Username = bid.User?.Username ?? "Unknown",
                AuctionId = bid.AuctionId
            };
        }

        public async Task<bool> DeleteBid(int bidId, int userId)
        {
            var bid = await _bidRepo.GetById(bidId);
            if (bid == null)
            {
                return false;
            }

            if (bid.UserId != userId)
            {
                return false;
            }

            var auction = await _auctionRepo.GetById(bid.AuctionId);
            if (auction == null || auction.EndDate < DateTime.UtcNow)
            {
                return false;
            }

            var highestBid = await _bidRepo.GetHighestBidForAuction(bid.AuctionId);
            if (bid.Amount != highestBid)
            {
                return false;
            }

            return await _bidRepo.Delete(bidId);
        }

        public async Task<BidResponseDto?> GetBidById(int bidId)
        {
            var bid = await _bidRepo.GetById(bidId);
            return bid == null ? null : MapToDto(bid);
        }

        public async Task<List<BidResponseDto>> GetBidsForAuction(int auctionId)
        {
            var bids = await _bidRepo.GetBidsForAuction(auctionId);
            return bids.Select(MapToDto).ToList();
        }

        public async Task<BidResponseDto?> PlaceBid(int userId, PlaceBidDto dto)
        {
            var user = await _userRepo.GetById(userId);
            if (user == null)
            {
                return null;
            }

            var auction = await _auctionRepo.GetById(dto.AuctionId);
            if (auction == null || !auction.IsActive)
            {
                return null;
            }


            if (auction.EndDate < DateTime.UtcNow)
            {
                return null;
            }

            if (auction.UserId == userId)
            {
                return null;
            }

            var currentHighest = await _bidRepo.GetHighestBidForAuction(dto.AuctionId);

            var minimumBid = currentHighest > 0 ? currentHighest : auction.StartingPrice;

            if (dto.Amount <= minimumBid)
            {
                return null;
            }

            var bid = new Bid
            {
                Amount = dto.Amount,
                BidDate = DateTime.UtcNow,
                UserId = userId,
                AuctionId = dto.AuctionId
            };

            var created = await _bidRepo.Create(bid);
            return MapToDto(created);
        }

        public async Task<BidResponseDto?> GetHighestBidForAuction(int auctionId)
        {
            var bids = await _bidRepo.GetBidsForAuction(auctionId);
            var highestBid = bids.OrderByDescending(b => b.Amount).FirstOrDefault();
            return highestBid == null ? null : MapToDto(highestBid);
        }
    }
}
