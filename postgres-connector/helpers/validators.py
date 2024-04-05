import sys
from helpers.constants import *


class InputValidators:
    @staticmethod
    def validate_input_arguments(arguments: list[str]) -> None:
        minimal_number_of_arguments = 2

        if len(arguments) < minimal_number_of_arguments:
            print("Number of arguments in the program should == 2")
            print("There should be: path_to_data_file: str: string")
            sys.exit(OutputConstants.EXIT_FAILURE)

        if len(arguments) > minimal_number_of_arguments and len(arguments) != 5:
            print("Wrong number of arguments in the program")
            print("There should be [path_to_data_file]: str, [ip_address_to_db]: str, [username_db]: str, [password_db]: str")
            sys.exit(1)