"""variables"""

class Variables:
    variables = {}
    def set(name, value):
        return None

    def set(name, value):
        """
        Set the variable by name and value.
        """
        if name in Variables.variables:
            raise ValueError("Duplicate variable name")
        Variables.variables[name] = value

    def get(name):
        """
        Return variable value using name
        """
        if name in Variables.variables:
            return Variables.variables[name]
        return None

