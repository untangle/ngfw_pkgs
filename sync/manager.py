class Manager:
    """
    Base manager class with stub methods
    """
    def initialize(self):
        """
        Initialization.
        Here managers call register methods to associate
        files with operations, settings_file identifiers the
        manager is intersted in, etc.
        """
        pass

    def sanitize_settings(self, settings_file):
        """
        Perform santiization on settings meant to be written back.
        """
        pass

    def validate_settings(self, settings_file):
        """
        Perform validation of settings
        """
        pass

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """
        Create new settings for the appopriate settings_file
        """
        pass

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Create appropriate system files from settings.
        """
        pass
