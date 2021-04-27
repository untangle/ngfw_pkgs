class Colors:
    BLACK_FOREGROUND = "\33[38;5;0m"
    WHITE_FOREGROUND = "\33[38;5;15m"

    BLACK_BACKGROUND = "\33[48;5m"
    # BLUE_BACKGROUND = "\33[48;5;20m"
    BLUE_BACKGROUND = "\33[48;5;21m"
    # RED_BACKGROUND = "\33[48;5;1m"
    RED_BACKGROUND = "\33[48;5;196m"
    GREEN_BACKGROUND = "\33[48;5;2m"
    CYAN_BACKGROUND = "\33[48;5;44m"
    GREY_BACKGROUND = "\33[48;5;250m"
    # YELLOW_BACKGROUND = "\33[48;5;11m"
    YELLOW_BACKGROUND = "\33[48;5;226m"

    END_TEXT = "\33[0m"

    FORMAT = "{background}{foreground}{text}{end}"

    @classmethod
    def format(cls,text, foreground=None, background=None):
        if foreground is None:
            foreground = Colors.WHITE_FOREGROUND
        if background is None:
            background = Colors.BLACK_BACKGROUND
        args = {
            "foreground": foreground,
            "background": background,
            "text": text,
            "end": Colors.END_TEXT
        }
        return Colors.FORMAT.format(**args)