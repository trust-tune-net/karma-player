"""AI session tracking for tokens and costs."""

from typing import Optional
from dataclasses import dataclass, field
from litellm import completion_cost


@dataclass
class AISessionStats:
    """Statistics for an AI session."""

    total_tokens: int = 0
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_cost: float = 0.0
    api_calls: int = 0
    model_name: str = ""

    def __str__(self) -> str:
        """Human-readable summary."""
        cost_str = f"${self.total_cost:.4f}" if self.total_cost > 0 else "$0.0000"
        return (
            f"AI Usage: {self.total_tokens:,} tokens "
            f"({self.prompt_tokens:,} in / {self.completion_tokens:,} out) • "
            f"{self.api_calls} calls • {cost_str}"
        )


class AISessionTracker:
    """Track AI token usage and costs across a session."""

    def __init__(self, model: str = "gpt-4o-mini"):
        """Initialize tracker.

        Args:
            model: The AI model being used
        """
        self.stats = AISessionStats(model_name=model)

    def track_response(self, response) -> None:
        """Track a completion response.

        Args:
            response: LiteLLM completion response
        """
        try:
            # Get usage from response
            usage = response.usage
            if usage:
                self.stats.prompt_tokens += getattr(usage, 'prompt_tokens', 0)
                self.stats.completion_tokens += getattr(usage, 'completion_tokens', 0)
                self.stats.total_tokens += getattr(usage, 'total_tokens', 0)

            # Calculate cost
            try:
                cost = completion_cost(completion_response=response)
                if cost:
                    self.stats.total_cost += float(cost)
            except Exception:
                # Cost calculation might fail for some models
                pass

            self.stats.api_calls += 1

        except Exception:
            # Don't crash if tracking fails
            pass

    def get_summary(self) -> str:
        """Get a formatted summary of the session.

        Returns:
            Formatted string with usage statistics
        """
        return str(self.stats)

    def get_stats(self) -> AISessionStats:
        """Get the raw statistics.

        Returns:
            AISessionStats object
        """
        return self.stats
