"""Tests for username generator service."""

import pytest
from karma_player.services.username_generator import (
    UsernameGenerator,
    generate_username,
    generate_username_with_parts,
    ADJECTIVES,
    NOUNS,
)


class TestUsernameGenerator:
    """Test username generation logic."""

    def test_generates_deterministic_username(self):
        """Same device_id should always generate same username."""
        device_id = "550e8400-e29b-41d4-a716-446655440000"
        generator = UsernameGenerator()

        username1 = generator.generate(device_id)
        username2 = generator.generate(device_id)

        assert username1 == username2

    def test_different_devices_get_different_usernames(self):
        """Different device_ids should generate different usernames."""
        device_id1 = "550e8400-e29b-41d4-a716-446655440000"
        device_id2 = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
        generator = UsernameGenerator()

        username1 = generator.generate(device_id1)
        username2 = generator.generate(device_id2)

        assert username1 != username2

    def test_username_format(self):
        """Username should follow Adjective-Noun-Number format."""
        device_id = "550e8400-e29b-41d4-a716-446655440000"
        generator = UsernameGenerator()

        username = generator.generate(device_id)

        # Should have exactly 2 hyphens
        parts = username.split('-')
        assert len(parts) == 3

        adjective, noun, number = parts

        # Adjective should be capitalized and in word list
        assert adjective[0].isupper()
        assert adjective in ADJECTIVES

        # Noun should be capitalized and in word list
        assert noun[0].isupper()
        assert noun in NOUNS

        # Number should be 4 digits
        assert number.isdigit()
        assert len(number) == 4
        assert 1000 <= int(number) <= 9999

    def test_generate_with_parts(self):
        """Should return username and individual components."""
        device_id = "550e8400-e29b-41d4-a716-446655440000"
        generator = UsernameGenerator()

        username, adjective, noun, number = generator.generate_with_parts(device_id)

        # Username should match format
        assert username == f"{adjective}-{noun}-{number}"

        # Components should be valid
        assert adjective in ADJECTIVES
        assert noun in NOUNS
        assert 1000 <= number <= 9999

    def test_custom_word_lists(self):
        """Should support custom adjective and noun lists."""
        custom_adjectives = ["Cool", "Awesome"]
        custom_nouns = ["Cat", "Dog"]
        device_id = "550e8400-e29b-41d4-a716-446655440000"

        generator = UsernameGenerator(
            adjectives=custom_adjectives,
            nouns=custom_nouns
        )

        username = generator.generate(device_id)
        parts = username.split('-')

        # Should use custom word lists
        assert parts[0] in custom_adjectives
        assert parts[1] in custom_nouns

    def test_global_generate_username(self):
        """Global generate_username function should work."""
        device_id = "550e8400-e29b-41d4-a716-446655440000"

        username = generate_username(device_id)

        # Should follow correct format
        parts = username.split('-')
        assert len(parts) == 3
        assert parts[0] in ADJECTIVES
        assert parts[1] in NOUNS

    def test_global_generate_username_with_parts(self):
        """Global generate_username_with_parts function should work."""
        device_id = "550e8400-e29b-41d4-a716-446655440000"

        username, adjective, noun, number = generate_username_with_parts(device_id)

        assert username == f"{adjective}-{noun}-{number}"
        assert adjective in ADJECTIVES
        assert noun in NOUNS

    def test_multiple_device_ids_all_unique(self):
        """Generate usernames for many devices - should be diverse."""
        generator = UsernameGenerator()
        device_ids = [
            "550e8400-e29b-41d4-a716-446655440000",
            "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
            "7c9e6679-7425-40de-944b-e07fc1f90ae7",
            "886313e1-3b8a-5372-9b90-0c9aee199e5d",
            "987fbc97-4bed-5078-9f07-9141ba07c9f3",
        ]

        usernames = [generator.generate(device_id) for device_id in device_ids]

        # All should be unique (very high probability with large word lists)
        assert len(usernames) == len(set(usernames))

    def test_determinism_across_instances(self):
        """Different generator instances should produce same username."""
        device_id = "550e8400-e29b-41d4-a716-446655440000"

        generator1 = UsernameGenerator()
        generator2 = UsernameGenerator()

        username1 = generator1.generate(device_id)
        username2 = generator2.generate(device_id)

        assert username1 == username2

    def test_handles_various_uuid_formats(self):
        """Should work with different valid UUIDs."""
        generator = UsernameGenerator()

        # Different UUID variants
        uuids = [
            "550e8400-e29b-41d4-a716-446655440000",  # UUID v4
            "6ba7b810-9dad-11d1-80b4-00c04fd430c8",  # UUID v1
            "a3bb189e-8bf9-3888-9912-ace4e6543002",  # UUID v3
            "f47ac10b-58cc-5372-a567-0e02b2c3d479",  # UUID v5
        ]

        for uuid in uuids:
            username = generator.generate(uuid)
            parts = username.split('-')

            assert len(parts) == 3
            assert parts[0] in ADJECTIVES
            assert parts[1] in NOUNS
            assert parts[2].isdigit()

    def test_word_lists_have_good_coverage(self):
        """Word lists should have sufficient variety."""
        # Ensure reasonable number of words for diversity
        assert len(ADJECTIVES) >= 100
        assert len(NOUNS) >= 100

        # All words should be capitalized
        assert all(word[0].isupper() for word in ADJECTIVES)
        assert all(word[0].isupper() for word in NOUNS)

        # No duplicates
        assert len(ADJECTIVES) == len(set(ADJECTIVES))
        assert len(NOUNS) == len(set(NOUNS))

    def test_username_aesthetics(self):
        """Generated usernames should be reasonable length."""
        device_id = "550e8400-e29b-41d4-a716-446655440000"
        generator = UsernameGenerator()

        username = generator.generate(device_id)

        # Total length should be reasonable (not too long)
        # Format: Word-Word-1234 (min ~10 chars, max ~30 chars)
        assert 10 <= len(username) <= 35
