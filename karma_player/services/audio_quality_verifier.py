"""Audio quality verification using ffprobe."""

import json
import logging
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional

logger = logging.getLogger(__name__)


class AudioQualityVerifier:
    """Verify actual audio quality using ffprobe."""

    def __init__(self):
        """Initialize verifier with platform-specific ffprobe path."""
        self.ffprobe_path = self._find_ffprobe()

    def _find_ffprobe(self) -> Optional[str]:
        """Find ffprobe binary on the system."""
        # Try common locations across platforms
        possible_paths = [
            "ffprobe",  # In PATH
            "/opt/homebrew/bin/ffprobe",  # macOS Homebrew (ARM)
            "/usr/local/bin/ffprobe",  # macOS Homebrew (Intel) / Linux
            "/usr/bin/ffprobe",  # Linux system
            "C:\\Program Files\\ffmpeg\\bin\\ffprobe.exe",  # Windows
            "C:\\ffmpeg\\bin\\ffprobe.exe",  # Windows alternative
        ]

        for path in possible_paths:
            try:
                result = subprocess.run(
                    [path, "-version"],
                    capture_output=True,
                    timeout=2,
                    check=False
                )
                if result.returncode == 0:
                    logger.info(f"✓ Found ffprobe at: {path}")
                    return path
            except (FileNotFoundError, subprocess.TimeoutExpired):
                continue

        logger.error("❌ ffprobe not found on system")
        return None

    def analyze_file(self, file_path: str) -> Dict[str, any]:
        """Analyze audio file and return quality information.

        Args:
            file_path: Path to audio file

        Returns:
            Dictionary with quality information:
            {
                "format": "flac",  # File format
                "codec": "flac",   # Audio codec
                "sample_rate": 96000,  # Hz
                "bit_depth": 24,  # bits (FLAC/WAV only)
                "bitrate": 2400000,  # bits per second
                "channels": 2,  # Stereo = 2
                "duration": 245.5,  # seconds
                "file_size": 89234567,  # bytes
                "quality_level": "Hi-Res",  # Hi-Res / CD / Lossy
                "verified": True
            }
        """
        if not self.ffprobe_path:
            return {"error": "ffprobe not available"}

        file_path = Path(file_path)
        if not file_path.exists():
            return {"error": f"File not found: {file_path}"}

        try:
            # Run ffprobe with JSON output
            cmd = [
                self.ffprobe_path,
                "-v", "quiet",
                "-print_format", "json",
                "-show_format",
                "-show_streams",
                "-select_streams", "a:0",  # First audio stream
                str(file_path)
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10,
                check=True
            )

            data = json.loads(result.stdout)
            return self._parse_ffprobe_output(data, file_path)

        except subprocess.TimeoutExpired:
            logger.error(f"ffprobe timeout for file: {file_path}")
            return {"error": "Analysis timeout"}
        except subprocess.CalledProcessError as e:
            logger.error(f"ffprobe error: {e}")
            return {"error": f"ffprobe failed: {e}"}
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse ffprobe output: {e}")
            return {"error": "Invalid ffprobe output"}
        except Exception as e:
            logger.error(f"Unexpected error analyzing file: {e}")
            return {"error": str(e)}

    def _parse_ffprobe_output(self, data: Dict, file_path: Path) -> Dict[str, any]:
        """Parse ffprobe JSON output into quality information."""
        result = {
            "file_path": str(file_path),
            "file_name": file_path.name,
            "verified": True
        }

        # Parse format information
        if "format" in data:
            format_info = data["format"]
            result["format"] = format_info.get("format_name", "unknown")
            result["duration"] = float(format_info.get("duration", 0))
            result["file_size"] = int(format_info.get("size", 0))

            # Overall bitrate from container
            if "bit_rate" in format_info:
                result["container_bitrate"] = int(format_info["bit_rate"])

        # Parse audio stream information
        if "streams" in data and len(data["streams"]) > 0:
            stream = data["streams"][0]

            # Codec
            result["codec"] = stream.get("codec_name", "unknown")

            # Sample rate (Hz)
            if "sample_rate" in stream:
                result["sample_rate"] = int(stream["sample_rate"])

            # Bit depth (for lossless formats)
            if "bits_per_sample" in stream:
                result["bit_depth"] = int(stream["bits_per_sample"])
            elif "bits_per_raw_sample" in stream:
                result["bit_depth"] = int(stream["bits_per_raw_sample"])

            # Bitrate (stream-specific)
            if "bit_rate" in stream:
                result["bitrate"] = int(stream["bit_rate"])

            # Channels
            if "channels" in stream:
                result["channels"] = int(stream["channels"])

            # Channel layout
            if "channel_layout" in stream:
                result["channel_layout"] = stream["channel_layout"]

        # Determine quality level
        result["quality_level"] = self._determine_quality_level(result)

        # Create human-readable summary
        result["quality_summary"] = self._create_quality_summary(result)

        return result

    def _determine_quality_level(self, info: Dict) -> str:
        """Determine quality level based on audio specs."""
        codec = info.get("codec", "").lower()
        sample_rate = info.get("sample_rate", 0)
        bit_depth = info.get("bit_depth", 0)
        bitrate = info.get("bitrate", 0)

        # Lossless formats
        if codec in ["flac", "alac", "ape", "wav", "aiff"]:
            if sample_rate >= 88200 or bit_depth >= 24:
                return "Hi-Res"  # Hi-Res: ≥24-bit or ≥88.2kHz
            elif sample_rate >= 44100 and bit_depth >= 16:
                return "CD Quality"  # CD: 16-bit/44.1kHz
            else:
                return "Lossless"

        # Lossy formats
        elif codec in ["mp3", "aac", "opus", "vorbis", "wma"]:
            if bitrate >= 320000:
                return "Lossy (320kbps)"
            elif bitrate >= 256000:
                return "Lossy (256kbps)"
            elif bitrate >= 192000:
                return "Lossy (192kbps)"
            elif bitrate >= 128000:
                return "Lossy (128kbps)"
            else:
                return "Lossy (Low)"

        return "Unknown"

    def _create_quality_summary(self, info: Dict) -> str:
        """Create human-readable quality summary."""
        codec = info.get("codec", "unknown").upper()

        # FLAC/Lossless
        if codec in ["FLAC", "ALAC", "APE", "WAV", "AIFF"]:
            bit_depth = info.get("bit_depth")
            sample_rate = info.get("sample_rate")

            if bit_depth and sample_rate:
                # Convert Hz to kHz
                sample_rate_khz = sample_rate / 1000
                return f"{codec} {bit_depth}/{sample_rate_khz:.1f}"
            elif bit_depth:
                return f"{codec} {bit_depth}-bit"
            elif sample_rate:
                sample_rate_khz = sample_rate / 1000
                return f"{codec} {sample_rate_khz:.1f}kHz"
            else:
                return codec

        # Lossy formats
        elif codec in ["MP3", "AAC", "OPUS", "VORBIS", "WMA"]:
            bitrate = info.get("bitrate", 0)
            if bitrate:
                bitrate_kbps = bitrate / 1000
                return f"{codec} {bitrate_kbps:.0f}kbps"
            else:
                return codec

        return codec


def main():
    """CLI interface for testing."""
    if len(sys.argv) < 2:
        print("Usage: python audio_quality_verifier.py <audio_file>")
        sys.exit(1)

    file_path = sys.argv[1]
    verifier = AudioQualityVerifier()
    result = verifier.analyze_file(file_path)

    if "error" in result:
        print(f"❌ Error: {result['error']}")
        sys.exit(1)

    # Print results
    print("\n📊 Audio Quality Analysis")
    print("=" * 50)
    print(f"File: {result['file_name']}")
    print(f"Format: {result.get('format', 'unknown')}")
    print(f"Codec: {result.get('codec', 'unknown').upper()}")
    print(f"Quality: {result['quality_level']}")
    print(f"Summary: {result['quality_summary']}")
    print()

    if "sample_rate" in result:
        print(f"Sample Rate: {result['sample_rate']} Hz ({result['sample_rate']/1000:.1f} kHz)")

    if "bit_depth" in result:
        print(f"Bit Depth: {result['bit_depth']}-bit")

    if "bitrate" in result:
        print(f"Bitrate: {result['bitrate']/1000:.0f} kbps")

    if "channels" in result:
        layout = result.get('channel_layout', 'unknown')
        print(f"Channels: {result['channels']} ({layout})")

    if "duration" in result:
        duration = result['duration']
        minutes = int(duration // 60)
        seconds = int(duration % 60)
        print(f"Duration: {minutes}:{seconds:02d}")

    if "file_size" in result:
        size_mb = result['file_size'] / (1024 * 1024)
        print(f"File Size: {size_mb:.2f} MB")

    print("=" * 50)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    main()
