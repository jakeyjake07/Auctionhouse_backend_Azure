namespace Auctionhouse_backend.DTOs.Auction
{
    public class AuctionResponseDto
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal StartingPrice { get; set; }
        public decimal CurrentHighestBid { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int SellerId { get; set; }
        public string SellerName { get; set; } = string.Empty;
        public bool IsOpen { get; set; }
        public int BidCount { get; set; }
        public bool IsActive { get; set; }
    }
}
