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

    def sanitize_settings_pre(self, settings_file):
        """
        Perform santiization on settings meant to be written back before other calls.
        """
        pass

    def sanitize_settings(self, settings_file):
        """
        Perform santiization on settings meant to be written back.
        """
        pass

    def sanitize_settings_post(self, settings_file):
        """
        Perform santiization on settings meant to be written back after other calls.
        """
        pass

    def validate_settings(self, settings_file):
        """
        Perform validation of settings
        """
        pass

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """
        Create new settings for the appopriate settings_file.
        """
        # NOTE: Python class variables won't wok as we currently fork for call_without_permissions()
        pass

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Create appropriate system files from settings.
        """
        # NOTE: Python class variables won't wok as we currently fork for call_without_permissions()
        pass
