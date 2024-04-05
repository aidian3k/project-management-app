import logging
import psycopg
import sys
from helpers.constants import *
import pandas


class DatabaseManagement:
    def __init__(self, postgres_connection, temporary_table_name: str, validation_procedure_name: str):
        self.__postgres_connection = postgres_connection
        self.__temporary_table_name = temporary_table_name
        self.__validation_procedure_name = validation_procedure_name

    def delete_all_temporary_data(self):
        try:
            cursor = self.__postgres_connection.cursor()
            cursor.execute(f'delete from {self.__temporary_table_name}')
            self.__postgres_connection.commit()

            logging.debug('Deleted all temporary clients from table temporary_clients')
            cursor.close()
        except psycopg.Error as error:
            print("Error deleting data from the temporary table:", error)
            sys.exit(OutputConstants.EXIT_FAILURE)

    def write_temporary_data_into_table(self, csv_data_file_path: str) -> None:
        data_frame: pandas.DataFrame = pandas.read_csv(csv_data_file_path)

        try:
            cursor = self.__postgres_connection.cursor()
            number_of_arguments = int(len(data_frame.columns))
            argument_to_insert_query = ', '.join(['%s'] * number_of_arguments)
            columns_names = data_frame.columns.tolist()
            columns_to_insert_query = ', '.join(columns_names)

            for index, row in data_frame.iterrows():
                insert_query = f'insert into {self.__temporary_table_name}({columns_to_insert_query}) values({argument_to_insert_query})'
                values_of_row = list(row)
                cursor.execute(insert_query, values_of_row)

            self.__postgres_connection.commit()
            logging.debug(f'Successfully wrote data into the: [{self.__temporary_table_name}] table')
            cursor.close()
        except Exception as e:
            logging.error(f'Error while inserting into the table in db', e)
            sys.exit(OutputConstants.EXIT_FAILURE)

    def validate_temporary_data_and_write_to_destination_table(self):
        try:
            postgres_cursor = self.__postgres_connection.cursor()
            postgres_cursor.execute(f'select {self.__validation_procedure_name}()')
            result = int(postgres_cursor.fetchone()[0])

            if result == OutputConstants.EXIT_FAILURE:
                raise Exception('There is a problem with data - check database log table!')

            self.__postgres_connection.commit()
            postgres_cursor.close()
        except Exception as error:
            logging.error(f'There was an error while executing the validation procedure: {error}')
            sys.exit(OutputConstants.EXIT_FAILURE)
