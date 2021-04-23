import importlib
import os
import sys

from support_diagnostics import Configuration

class ImportModules:
    directory_imported_modules = {}

    base_directory = None

    @classmethod
    def static_init(cls):
        """
        Determine base directory to look for modules.
        """
        for path in sys.path:
            if os.path.isdir(path + "/support_diagnostics"):
                ImportModules.base_directory = path + "/support_diagnostics/platforms"

    @classmethod
    def import_all(cls, namespace, directory, target_platform=None):
        """
        Dynamically import modules instead of managing __init__.py

        Collectors, analyzers, report can have a lot od modules.
        """
        platform = target_platform
        if platform is None:
            platform = Configuration.platform

        module_key = '_'.join([directory, platform])

        if module_key not in ImportModules.directory_imported_modules:
            ImportModules.directory_imported_modules[module_key] = []
            glob_path = ImportModules.base_directory + "/{platform}/{directory}/".format(platform=platform,directory=directory)
            import_path = "support_diagnostics.platforms.{platform}.{directory}.".format(platform=platform,directory=directory)
            names = []
            for module in os.listdir(os.path.dirname(glob_path)):
                if module == '__init__.py' or module[-3:] != '.py':
                    continue
                module_path = import_path + module[:-3]
                imported_module = importlib.import_module(module_path)

                if "__all__" in imported_module.__dict__:
                    names = imported_module.__dict__["__all__"]
                else:
                    # otherwise we import all names that don't begin with _
                    names = [x for x in imported_module.__dict__ if not x.startswith("_")]

                ImportModules.directory_imported_modules[module_key].append({
                    'names': names,
                    'imported_module': imported_module
                })

        for module in ImportModules.directory_imported_modules[module_key]:
            for name in module['names']:
                namespace.update({name: getattr(module['imported_module'], name)})

        if target_platform is None:
            ImportModules.import_all(namespace, directory, "all")

if ImportModules.base_directory is None:
    ImportModules.static_init()