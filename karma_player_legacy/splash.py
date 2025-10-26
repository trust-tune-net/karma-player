"""Splash screen animation for karma-player startup."""

import random
from typing import Any

from textual.app import App
from textualeffects.effects import EffectType
from textualeffects.widgets import SplashScreen

logo = r'''
88      a8P         db        88888888ba  88b           d88        db           88888888ba  88                 db   8b        d8 88888888888 88888888ba
88    ,88'         d88b       88      "8b 888b         d888       d88b          88      "8b 88                d88b   Y8,    ,8P  88          88      "8b
88  ,88"          d8'`8b      88      ,8P 88`8b       d8'88      d8'`8b         88      ,8P 88               d8'`8b   Y8,  ,8P   88          88      ,8P
88,d88'          d8'  `8b     88aaaaaa8P' 88 `8b     d8' 88     d8'  `8b        88aaaaaa8P' 88              d8'  `8b   "8aa8"    88aaaaa     88aaaaaa8P'
8888"88,        d8YaaaaY8b    88""""88'   88  `8b   d8'  88    d8YaaaaY8b       88""""""'   88             d8YaaaaY8b   `88'     88"""""     88""""88'
88P   Y8b      d8""""""""8b   88    `8b   88   `8b d8'   88   d8""""""""8b      88          88            d8""""""""8b   88      88          88    `8b
88     "88,   d8'        `8b  88     `8b  88    `888'    88  d8'        `8b     88          88           d8'        `8b  88      88          88     `8b
88       Y8b d8'          `8b 88      `8b 88     `8'     88 d8'          `8b    88          88888888888 d8'          `8b 88      88888888888 88      `8b


                                                🎵 AI-powered music search 🎵
'''

effects: list[tuple[EffectType, dict[str, Any]]] = [
    (
        "Beams",
        {
            "beam_delay": 7,  # Slightly faster beams
            "beam_gradient_steps": 4,
            "beam_gradient_frames": 4,
            "final_gradient_steps": 4,
            "final_gradient_frames": 4,
            "final_wipe_speed": 3,  # Slightly faster wipe
        },
    ),
    (
        "BouncyBalls",
        {
            "ball_delay": 1,  # Slightly faster ball drops
        },
    ),
    (
        "Expand",
        {
            "movement_speed": 0.035,  # Slightly faster expansion
        },
    ),
    (
        "Pour",
        {
            "pour_speed": 2,  # Slightly faster pour (must be int)
        },
    ),
    (
        "Rain",
        {},
    ),
    (
        "RandomSequence",
        {},
    ),
    (
        "Scattered",
        {},
    ),
    (
        "Slide",
        {},
    ),
]


class SplashApp(App):
    """Temporary Textual app to show splash screen."""

    def on_mount(self) -> None:
        """Show splash screen on mount."""
        effect, config = random.choice(effects)
        splash_screen = SplashScreen(text=logo, effect=effect, config=config)

        def on_splash_done(message) -> None:
            """Exit app when splash is done, with pause to read."""
            # Use set_timer instead of asyncio.sleep to avoid race conditions
            self.set_timer(1.5, self.exit)

        self.push_screen(splash_screen, callback=on_splash_done)


def show_splash() -> None:
    """Show splash screen animation."""
    app = SplashApp()
    app.run()
