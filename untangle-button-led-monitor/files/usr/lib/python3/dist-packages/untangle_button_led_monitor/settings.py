
class Settings:
    """
    Singleton for settings.
    """
    Debug = False

    @classmethod
    def set(cls, key, value):
        """
        Set value
        """
        setattr(cls, key, value)
