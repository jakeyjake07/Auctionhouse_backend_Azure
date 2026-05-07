using Auctionhouse_backend.DTOs.Auction;

namespace Auctionhouse_backend.Core.Interfaces
{
    public interface IAuctionService
    {

        Task<AuctionResponseDto?> CreateAuction(int userId, CreateAuctionDto dto);
        Task<AuctionResponseDto?> UpdateAuction(int auctionId, int userId, UpdateAuctionDto dto);
        Task<bool> DeleteAuction(int auctionId, int userId);


        Task<AuctionResponseDto?> GetAuctionById(int auctionId);
        Task<List<AuctionResponseDto>> GetOpenAuctions();
        Task<List<AuctionResponseDto>> SearchAuctions(string title);
        Task<List<AuctionResponseDto>> GetUserAuctions(int userId);


        Task<List<AuctionResponseDto>> GetAllAuctions(bool includeClosed);
        Task<List<AuctionResponseDto>> SearchAllAuctions(string title, bool includeClosed);
        Task<bool> ToggleAuctionActive(int auctionId, int adminId);
    }
}
