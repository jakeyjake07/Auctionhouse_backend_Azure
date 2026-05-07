using Auctionhouse_backend.Core.Interfaces;
using Auctionhouse_backend.Data.Entities;
using Auctionhouse_backend.Data.Interfaces;
using Auctionhouse_backend.DTOs.Auction;

namespace Auctionhouse_backend.Core.Services
{
    public class AuctionService : IAuctionService
    {

        private readonly IAuctionRepo _auctionRepo;
        private readonly IUserRepo _userRepo;
        private readonly IBidRepo _bidRepo;

        public AuctionService(IAuctionRepo auctionRepo, IUserRepo userRepo, IBidRepo bidRepo)
        {
            _auctionRepo = auctionRepo;
            _userRepo = userRepo;
            _bidRepo = bidRepo;
        }

        private AuctionResponseDto MapToDto(Auction auction)
        {

            var highestBid = auction.StartingPrice;
            if (auction.Bids != null && auction.Bids.Any())
            {
                highestBid = auction.Bids.Max(b => b.Amount);
            }

            return new AuctionResponseDto
            {
                Id = auction.Id,
                Title = auction.Title,
                Description = auction.Description,
                StartingPrice = auction.StartingPrice,
                CurrentHighestBid = highestBid,
                StartDate = auction.StartDate,
                EndDate = auction.EndDate,
                SellerId = auction.UserId,
                SellerName = auction.User?.Username ?? "Unknown",
                IsOpen = auction.EndDate > DateTime.UtcNow,
                BidCount = auction.Bids?.Count ?? 0,
                IsActive = auction.IsActive
            };
        }

        public async Task<AuctionResponseDto?> CreateAuction(int userId, CreateAuctionDto dto)
        {
            var user = await _userRepo.GetById(userId);
            if (user == null)
            {
                return null;
            }

            var auction = new Auction
            {
                Title = dto.Title,
                Description = dto.Description,
                StartingPrice = dto.StartingPrice,
                StartDate = DateTime.UtcNow,
                EndDate = dto.EndDate,
                UserId = userId,
                IsActive = true
            };

            var created = await _auctionRepo.Create(auction);
            return MapToDto(created);

        }

        public async Task<bool> DeleteAuction(int auctionId, int userId)
        {
            if (!await _auctionRepo.UserOwnsAuction(auctionId, userId))
            {
                return false;
            }

            return await _auctionRepo.Delete(auctionId);
        }

        public async Task<AuctionResponseDto?> GetAuctionById(int auctionId)
        {
            var auction = await _auctionRepo.GetById(auctionId);
            if (auction == null)
            {
                return null;
            }
            return MapToDto(auction);
        }

        public async Task<List<AuctionResponseDto>> GetOpenAuctions()
        {
            var auctions = await _auctionRepo.GetOpenAuctions();
            var result = new List<AuctionResponseDto>();

            foreach (var auction in auctions)
            {
                result.Add(MapToDto(auction));
            }

            return result;
        }

        public async Task<List<AuctionResponseDto>> GetUserAuctions(int userId)
        {
            var auctions = await _auctionRepo.GetAuctionByUser(userId);
            var result = new List<AuctionResponseDto>();

            foreach (var auction in auctions)
            {
                result.Add(MapToDto(auction));
            }

            return result;

        }

        public async Task<List<AuctionResponseDto>> SearchAllAuctions(bool includeClosed)
        {

            List<Auction> auctions;

            if (includeClosed)
            {

                auctions = await _auctionRepo.GetAllAuctions();
            }
            else
            {
                auctions = await _auctionRepo.GetOpenAuctions();
            }

            var result = new List<AuctionResponseDto>();

            foreach (var auction in auctions)
            {
                result.Add(MapToDto(auction));
            }
            return result;
        }

        public async Task<List<AuctionResponseDto>> SearchAuctions(string title)
        {
            var auctions = await _auctionRepo.SearchByTitle(title);
            var result = new List<AuctionResponseDto>();

            foreach (var auction in auctions)
            {
                result.Add(MapToDto(auction));
            }

            return result;
        }

        public async Task<bool> ToggleAuctionActive(int auctionId, int adminId)
        {
            var auction = await _auctionRepo.GetById(auctionId);
            if (auction == null)
            {
                return false;
            }

            auction.IsActive = !auction.IsActive;
            await _auctionRepo.Update(auction);
            return true;

        }

        public async Task<AuctionResponseDto?> UpdateAuction(int auctionId, int userId, UpdateAuctionDto dto)
        {
            if (!await _auctionRepo.UserOwnsAuction(auctionId, userId))
            {
                return null;
            }

            var auction = await _auctionRepo.GetById(auctionId);

            if (auction == null)
            {
                return null;

            }

            var hasBids = auction.Bids != null && auction.Bids.Any();
            if (hasBids && dto.StartingPrice.HasValue)
            {
                return null;
            }

            if (!string.IsNullOrWhiteSpace(dto.Title))
            {
                auction.Title = dto.Title;
            }

            if (!string.IsNullOrWhiteSpace(dto.Description))
            {
                auction.Description = dto.Description;

            }

            if (!hasBids && dto.StartingPrice.HasValue)
            {
                auction.StartingPrice = dto.StartingPrice.Value;
            }

            if (dto.EndDate.HasValue && dto.EndDate.Value > DateTime.UtcNow)
            {
                auction.EndDate = dto.EndDate.Value;
            }

            var updated = await _auctionRepo.Update(auction);
            return MapToDto(updated);
        }

        public async Task<List<AuctionResponseDto>> SearchAllAuctions(string title, bool includeClosed)
        {
            List<Auction> auctions;

            if (includeClosed)
            {
                auctions = await _auctionRepo.SearchAllAuctions(title);
            }
            else
            {
                auctions = await _auctionRepo.SearchByTitle(title);
            }

            return auctions.Select(MapToDto).ToList();
        }

        public async Task<List<AuctionResponseDto>> GetAllAuctions(bool includeClosed)
        {
            List<Auction> auctions;

            if (includeClosed)
            {
                auctions = await _auctionRepo.GetAllAuctions();
            }
            else
            {
                auctions = await _auctionRepo.GetOpenAuctions();
            }

            return auctions.Select(MapToDto).ToList();
        }
    }
}
