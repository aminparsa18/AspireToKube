namespace AspireToKube.ApiService.Models;

public class Zombie
{
    public int Id { get; set; }
    public string? Name { get; set; }
    public string? Type { get; set; }
    public bool IsDangerous { get; set; }
    public int BrainsConsumed { get; set; }
    public int ShuffleSpeed { get; set; } // in meters per hour
    public HumanPart FavoriteHumanPart { get; set; } 

    public string Moan()
    {
        return "Braaaaaains...";
    }

    public string GetHungerLevel()
    {
        return BrainsConsumed switch
        {
            0 => "STARVING! 🧟",
            < 5 => "Very hungry",
            < 10 => "Peckish",
            < 20 => "Satisfied",
            _ => "Well-fed (for now...)"
        };
    }

    public enum HumanPart
    {
        Brain,
        MoreBrains
    }
}