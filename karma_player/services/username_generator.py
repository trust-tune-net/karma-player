"""
Reddit-style username generator for TrustTune.

Generates deterministic usernames based on device_id using the format:
    Adjective-Noun-Numbers (e.g., "Feisty-Sky-6018")

Uses device_id as seed to ensure same device always gets same username.
"""

import hashlib
import random
from typing import Tuple


# Curated word lists for aesthetically pleasing combinations
ADJECTIVES = [
    "Adorable", "Adventurous", "Ambitious", "Amused", "Artistic",
    "Authentic", "Awesome", "Blissful", "Bold", "Brave",
    "Bright", "Brilliant", "Calm", "Charming", "Cheerful",
    "Clever", "Colorful", "Cool", "Cosmic", "Creative",
    "Curious", "Dapper", "Daring", "Dazzling", "Delightful",
    "Dynamic", "Eager", "Earnest", "Eccentric", "Electric",
    "Elegant", "Enchanted", "Energetic", "Epic", "Ethereal",
    "Excellent", "Excited", "Exotic", "Fabulous", "Fancy",
    "Fearless", "Feisty", "Fierce", "Flawless", "Friendly",
    "Funky", "Gentle", "Genuine", "Gleaming", "Glorious",
    "Golden", "Graceful", "Grand", "Happy", "Harmonious",
    "Heroic", "Honest", "Hopeful", "Humble", "Imaginative",
    "Incredible", "Inspired", "Intrepid", "Jolly", "Joyful",
    "Keen", "Kind", "Legendary", "Lively", "Loving",
    "Loyal", "Lucky", "Luminous", "Majestic", "Marvelous",
    "Mellow", "Mighty", "Miraculous", "Mysterious", "Mystical",
    "Natural", "Noble", "Optimistic", "Passionate", "Peaceful",
    "Perfect", "Persistent", "Playful", "Pleasant", "Poetic",
    "Polished", "Powerful", "Precious", "Prime", "Proud",
    "Pure", "Quiet", "Radiant", "Rapid", "Rational",
    "Relaxed", "Reliable", "Resonant", "Rhythmic", "Royal",
    "Rustic", "Sacred", "Savvy", "Serene", "Sharp",
    "Shiny", "Silent", "Silly", "Silver", "Simple",
    "Sincere", "Sleek", "Smart", "Smooth", "Snazzy",
    "Solid", "Soulful", "Sparkling", "Spectacular", "Spirited",
    "Stellar", "Sterling", "Strong", "Stunning", "Sublime",
    "Sunny", "Super", "Sweet", "Swift", "Timeless",
    "Tranquil", "True", "Trusty", "Ultimate", "Unique",
    "Upbeat", "Valiant", "Vibrant", "Victorious", "Vivid",
    "Warm", "Wild", "Wise", "Witty", "Wonderful",
    "Worthy", "Zealous", "Zen",
]

NOUNS = [
    "Aardvark", "Albatross", "Angel", "Asteroid", "Aurora",
    "Badger", "Banjo", "Bear", "Bee", "Bison",
    "Blaze", "Breeze", "Buffalo", "Butterfly", "Canyon",
    "Castle", "Cedar", "Cloud", "Comet", "Coral",
    "Cosmos", "Coyote", "Cricket", "Crystal", "Dawn",
    "Delta", "Desert", "Diamond", "Dolphin", "Dragon",
    "Dream", "Eagle", "Echo", "Eclipse", "Ember",
    "Emerald", "Falcon", "Fern", "Fire", "Flame",
    "Forest", "Fox", "Galaxy", "Garden", "Glacier",
    "Grove", "Guitar", "Hawk", "Horizon", "Hurricane",
    "Island", "Ivory", "Jade", "Jaguar", "Jazz",
    "Jewel", "Journey", "Jungle", "Karma", "Kestrel",
    "Kite", "Lake", "Lark", "Lightning", "Lion",
    "Lotus", "Lynx", "Maple", "Meadow", "Melody",
    "Mesa", "Meteor", "Moon", "Mountain", "Nebula",
    "Night", "Nova", "Ocean", "Opal", "Orchid",
    "Otter", "Owl", "Panther", "Paradise", "Pearl",
    "Pebble", "Phoenix", "Piano", "Planet", "Prairie",
    "Prism", "Pulse", "Quasar", "Quest", "Rain",
    "Rainbow", "Raven", "Rhythm", "River", "Rock",
    "Rose", "Ruby", "Sage", "Sapphire", "Seagull",
    "Shadow", "Sky", "Snow", "Solstice", "Song",
    "Songbird", "Soul", "Sound", "Spark", "Spirit",
    "Spring", "Star", "Stone", "Storm", "Stream",
    "Summer", "Summit", "Sun", "Sunrise", "Sunset",
    "Swan", "Symphony", "Thunder", "Tiger", "Trail",
    "Tree", "Tsunami", "Twilight", "Universe", "Valley",
    "Velvet", "Violet", "Vision", "Volcano", "Wave",
    "Whisper", "Wind", "Winter", "Wolf", "Wonder",
    "Zephyr", "Zenith",
]


class UsernameGenerator:
    """Generates deterministic Reddit-style usernames from device IDs."""

    def __init__(self, adjectives: list[str] = None, nouns: list[str] = None):
        """
        Initialize the username generator.

        Args:
            adjectives: Custom adjective list (uses default if None)
            nouns: Custom noun list (uses default if None)
        """
        self.adjectives = adjectives or ADJECTIVES
        self.nouns = nouns or NOUNS

    def generate(self, device_id: str) -> str:
        """
        Generate a deterministic username from a device ID.

        Format: Adjective-Noun-Numbers (e.g., "Feisty-Sky-6018")

        Args:
            device_id: UUID v4 device identifier

        Returns:
            Generated username (e.g., "Feisty-Sky-6018")

        Examples:
            >>> gen = UsernameGenerator()
            >>> gen.generate("550e8400-e29b-41d4-a716-446655440000")
            'Feisty-Sky-6018'
            >>> gen.generate("550e8400-e29b-41d4-a716-446655440000")
            'Feisty-Sky-6018'  # Same device_id = same username
        """
        # Use SHA-256 hash of device_id as seed for determinism
        hash_bytes = hashlib.sha256(device_id.encode('utf-8')).digest()

        # Convert first 8 bytes to integer seed
        seed = int.from_bytes(hash_bytes[:8], byteorder='big')

        # Create seeded random generator
        rng = random.Random(seed)

        # Select adjective and noun deterministically
        adjective = rng.choice(self.adjectives)
        noun = rng.choice(self.nouns)

        # Generate 4-digit number (1000-9999) deterministically
        number = rng.randint(1000, 9999)

        # Format as Reddit-style username
        return f"{adjective}-{noun}-{number}"

    def generate_with_parts(self, device_id: str) -> Tuple[str, str, str, int]:
        """
        Generate username and return individual components.

        Args:
            device_id: UUID v4 device identifier

        Returns:
            Tuple of (full_username, adjective, noun, number)

        Examples:
            >>> gen = UsernameGenerator()
            >>> username, adj, noun, num = gen.generate_with_parts("550e8400-...")
            >>> username
            'Feisty-Sky-6018'
            >>> (adj, noun, num)
            ('Feisty', 'Sky', 6018)
        """
        # Use same deterministic logic
        hash_bytes = hashlib.sha256(device_id.encode('utf-8')).digest()
        seed = int.from_bytes(hash_bytes[:8], byteorder='big')
        rng = random.Random(seed)

        adjective = rng.choice(self.adjectives)
        noun = rng.choice(self.nouns)
        number = rng.randint(1000, 9999)

        username = f"{adjective}-{noun}-{number}"

        return username, adjective, noun, number


# Global singleton instance
_generator = UsernameGenerator()


def generate_username(device_id: str) -> str:
    """
    Generate a Reddit-style username from a device ID.

    This is a convenience function that uses the global generator instance.

    Args:
        device_id: UUID v4 device identifier

    Returns:
        Generated username (e.g., "Feisty-Sky-6018")

    Examples:
        >>> generate_username("550e8400-e29b-41d4-a716-446655440000")
        'Feisty-Sky-6018'
    """
    return _generator.generate(device_id)


def generate_username_with_parts(device_id: str) -> Tuple[str, str, str, int]:
    """
    Generate username and return individual components.

    This is a convenience function that uses the global generator instance.

    Args:
        device_id: UUID v4 device identifier

    Returns:
        Tuple of (full_username, adjective, noun, number)
    """
    return _generator.generate_with_parts(device_id)
