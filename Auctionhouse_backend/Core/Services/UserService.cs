using Auctionhouse_backend.Core.Interfaces;
using Auctionhouse_backend.Data.Entities;
using Auctionhouse_backend.Data.Interfaces;
using Auctionhouse_backend.DTOs.User;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Auctionhouse_backend.Core.Services
{
    public class UserService : IUserService
    {
        private readonly IUserRepo _userRepo;
        private readonly IPasswordService _passwordService;
        private readonly IConfiguration _configuration;

        public UserService(IUserRepo userRepo, IPasswordService passwordService, IConfiguration configuration)
        {
            _userRepo = userRepo;
            _passwordService = passwordService;
            _configuration = configuration;
        }

        private string GenerateJwtToken(User user)
        {
            var jwtSettings = _configuration.GetSection("JwtSettings");

            var claims = new List<Claim>
            {
                new Claim("id", user.Id.ToString()),
                new Claim("username", user.Username),
                new Claim("email", user.Email),
                new Claim("isAdmin", user.IsAdmin.ToString())
            };

            var secretKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings["Key"]));

            var signingCredentials = new SigningCredentials(secretKey, SecurityAlgorithms.HmacSha256);

            var tokenOptions = new JwtSecurityToken(
                issuer: jwtSettings["Issuer"],
                audience: jwtSettings["Audience"],
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(double.Parse(jwtSettings["ExpiresInMinutes"])),
                signingCredentials: signingCredentials
            );

            return new JwtSecurityTokenHandler().WriteToken(tokenOptions);
        }

        public async Task<bool> ChangePassword(int userId, string currentPassword, string newPassword)
        {
            var user = await _userRepo.GetById(userId);
            if (user == null)
            {
                return false;
            }

            if (!_passwordService.VerifyPassword(currentPassword, user.PasswordHash))
            {
                return false;
            }

            user.PasswordHash = _passwordService.HashPassword(newPassword);
            await _userRepo.Update(user);
            return true;
        }

        public async Task<bool> DeleteUser(int id)
        {
            return await _userRepo.Delete(id);
        }

        public async Task<UserResponseDto?> GetUserById(int id)
        {
            var user = await _userRepo.GetById(id);
            if (user == null)
            {
                return null;
            }

            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email
            };
        }

        public async Task<LoginResponseDto?> Login(LoginDto loginDto)
        {
            var user = await _userRepo.GetByUsername(loginDto.Username);

            if (user == null || !user.IsActive)
            {
                return null;
            }

            if (!_passwordService.VerifyPassword(loginDto.Password, user.PasswordHash))
            {
                return null;
            }

            var token = GenerateJwtToken(user);

            return new LoginResponseDto
            {
                UserId = user.Id,
                Username = user.Username,
                Email = user.Email,
                Token = token
            };
        }

        public async Task<LoginResponseDto?> Register(RegisterDto registerDto)
        {
            if (await _userRepo.UsernameExists(registerDto.Username))
            {

                return null;
            }

            if (await _userRepo.EmailExists(registerDto.Email))
            {
                return null;
            }

            var user = new User
            {
                Username = registerDto.Username,
                Email = registerDto.Email,
                PasswordHash = _passwordService.HashPassword(registerDto.Password),
                IsActive = true
            };

            var createdUser = await _userRepo.Create(user);
            var token = GenerateJwtToken(createdUser);

            return new LoginResponseDto
            {
                UserId = createdUser.Id,
                Username = createdUser.Username,
                Email = createdUser.Email,
                Token = token
            };
        }

        public async Task<bool> ToggleUserActive(int userId, int adminId)
        {


            var admin = await _userRepo.GetById(adminId);
            if (admin == null || !admin.IsAdmin)
            {
                return false;
            }

            var user = await _userRepo.GetById(userId);
            if (user == null)
            {
                return false;
            }

            user.IsActive = !user.IsActive;
            await _userRepo.Update(user);
            return true;
        }

        public async Task<UserResponseDto?> UpdateUser(int id, UpdateUserDto updateUserDto)
        {
            var user = await _userRepo.GetById(id);
            if (user == null)
            {
                return null;
            }

            if (!string.IsNullOrWhiteSpace(updateUserDto.Email))
            {
                var existingUser = await _userRepo.GetByEmail(updateUserDto.Email);
                if (existingUser != null && existingUser.Id != id)
                {
                    return null;
                }

                user.Email = updateUserDto.Email;
            }

            var updatedUser = await _userRepo.Update(user);

            return new UserResponseDto
            {
                Id = updatedUser.Id,
                Username = updatedUser.Username,
                Email = updatedUser.Email
            };
        }

        public async Task<List<UserResponseDto>> GetAllUsers()
        {
            var users = await _userRepo.GetAllUsers();
            return users.Select(u => new UserResponseDto
            {
                Id = u.Id,
                Username = u.Username,
                Email = u.Email,
                IsActive = u.IsActive
            }).ToList();
        }

    }
}
