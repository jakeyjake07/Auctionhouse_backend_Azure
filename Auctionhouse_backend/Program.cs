using Auctionhouse_backend.Core.Interfaces;
using Auctionhouse_backend.Core.Services;
using Auctionhouse_backend.Data;
using Auctionhouse_backend.Data.Interfaces;
using Auctionhouse_backend.Data.Repos;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace Auctionhouse_backend
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            builder.Services.AddControllers();

            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowReactApp",
                    builder =>
                    {
                        builder.WithOrigins("https://purple-ocean-060399303.2.azurestaticapps.net")
                        .AllowAnyHeader()
                        .AllowAnyMethod()
                        .AllowCredentials();
                    });
            });

            var connString = builder.Configuration["DefaultConnection"];

            builder.Services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(connString));

            var jwtSettings = builder.Configuration.GetSection("JwtSettings");
            var key = Encoding.ASCII.GetBytes(jwtSettings["Key"]);

            builder.Services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            })
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = jwtSettings["Issuer"],
                    ValidAudience = jwtSettings["Audience"],
                    IssuerSigningKey = new SymmetricSecurityKey(key)
                };
            });


            builder.Services.AddScoped<IUserRepo, UserRepo>();
            builder.Services.AddScoped<IAuctionRepo, AuctionRepo>();
            builder.Services.AddScoped<IBidRepo, BidRepo>();


            builder.Services.AddScoped<IPasswordService, PasswordService>();
            builder.Services.AddScoped<IUserService, UserService>();
            builder.Services.AddScoped<IAuctionService, AuctionService>();
            builder.Services.AddScoped<IBidService, BidService>();
            builder.Services.AddOpenTelemetry().UseAzureMonitor();


            var app = builder.Build();

            app.UseCors("AllowReactApp");

            app.UseAuthentication();
            app.UseAuthorization();
            app.MapControllers();

            app.Run();
        }
    }
}
