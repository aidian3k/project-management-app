from helpers.constants import *
from helpers.database_management import *
from helpers.db_credentials import DatabaseCredentials
from helpers.validators import InputValidators

if __name__ == '__main__':
    InputValidators.validate_input_arguments(sys.argv)

    path_to_directory_with_data: str = sys.argv[1]
    database_credentials = DatabaseCredentials()

    postgres_connection = psycopg.connect(
        dbname=database_credentials.database_name,
        user=database_credentials.username,
        password=database_credentials.password,
        host=database_credentials.ip_address,
        port=database_credentials.port
    )

    clients_file_path: str = f'{path_to_directory_with_data}/{FileNames.clients_file}'
    clients_db_management: DatabaseManagement = DatabaseManagement(postgres_connection,
                                                                   ClientConstants.temporary_table_name,
                                                                   ClientConstants.validation_procedure_name)
    clients_db_management.delete_all_temporary_clients_data()
    clients_db_management.write_temporary_data_into_table(clients_file_path)
