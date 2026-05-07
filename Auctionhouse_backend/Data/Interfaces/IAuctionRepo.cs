using Auctionhouse_backend.Data.Entities;

namespace Auctionhouse_backend.Data.Interfaces
{
    public interface IAuctionRepo
    {
        Task<Auction?> GetById(int id);
        Task<List<Auction>> GetOpenAuctions();
        Task<List<Auction>> SearchByTitle(string title);
        Task<List<Auction>> GetAuctionByUser(int userId);
        Task<Auction> Create(Auction auction);
        Task<Auction> Update(Auction auction);
        Task<bool> Delete(int id);
        Task<bool> UserOwnsAuction(int auctionId, int userId);
        Task<List<Auction>> GetAllAuctions();
        Task<List<Auction>> SearchAllAuctions(string title);
    }
}
