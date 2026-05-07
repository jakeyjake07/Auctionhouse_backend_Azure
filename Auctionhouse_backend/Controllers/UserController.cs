using Auctionhouse_backend.Core.Interfaces;
using Auctionhouse_backend.DTOs.User;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Auctionhouse_backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController : ControllerBase
    {
        private readonly IUserService _userService;

        public UserController(IUserService userService)
        {
            _userService = userService;
        }


        [HttpPost("register")]
        public async Task<IActionResult> Register(RegisterDto registerDto)
        {
            var result = await _userService.Register(registerDto);
            if (result == null)
            {
                return BadRequest("Username or email already exists.");
            }
            return Ok(result);
        }


        [HttpPost("login")]
        public async Task<IActionResult> Login(LoginDto loginDto)
        {
            var result = await _userService.Login(loginDto);
            if (result == null)
            {
                return Unauthorized("Invalid username or password.");
            }
            return Ok(result);
        }

        [HttpGet("{id}")]
        [Authorize]
        public async Task<IActionResult> GetUserById(int id)
        {
            var result = await _userService.GetUserById(id);
            if (result == null)
            {
                return NotFound();
            }
            return Ok(result);


        }

        [HttpPut("{id}")]
        [Authorize]
        public async Task<IActionResult> UpdateUser(int id, UpdateUserDto updateUserDto)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");
            if (userId != id)
            {
                return Unauthorized("You can only update your own profile");
            }

            var result = await _userService.UpdateUser(id, updateUserDto);

            if (result == null)
            {
                return NotFound("User not found or email already taken");
            }

            return Ok(result);
        }


        [HttpPut("{id}/password")]
        [Authorize]
        public async Task<IActionResult> ChangePassword(int id, [FromBody] ChangePasswordDto changePasswordDto)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");
            if (userId != id)
            {
                return Unauthorized("You can only change your own password");
            }

            var result = await _userService.ChangePassword(id, changePasswordDto.CurrentPassword, changePasswordDto.NewPassword);

            if (!result)
            {
                return BadRequest("Current password is incorrect");
            }

            return Ok();
        }



        [HttpDelete("{id}")]
        [Authorize]
        public async Task<IActionResult> DeleteUser(int id)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");
            if (userId != id)
            {
                return Unauthorized("You can only delete your own account");
            }

            var result = await _userService.DeleteUser(id);

            if (!result)
            {
                return NotFound();
            }

            return NoContent();

        }

    }
}
