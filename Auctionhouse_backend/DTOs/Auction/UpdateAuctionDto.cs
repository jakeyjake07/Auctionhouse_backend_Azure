namespace Auctionhouse_backend.DTOs.Auction
{
    public class UpdateAuctionDto
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public decimal? StartingPrice { get; set; }
        public DateTime? EndDate { get; set; }
    }
}
