import logging

import psycopg
import sys

from pandas import DataFrame

import constants
import pandas


class DatabaseManagement:
    def __init__(self, postgres_connection, temporary_table_name: str, validation_procedure_name: str):
        self.__postgres_connection = postgres_connection
        self.__temporary_table_name = temporary_table_name
        self.__validation_procedure_name = validation_procedure_name

    def delete_all_temporary_clients_data(self):
        try:
            cursor = self.__postgres_connection.cursor()
            cursor.execute(f'delete from {self.__temporary_table_name}')
            cursor.commit()

            logging.debug('Deleted all temporary clients from table temporary_clients')
            cursor.close()
        except psycopg.Error as error:
            print("Error deleting data from the temporary table:", error)
            sys.exit(constants.OutputConstants.EXIT_FAILURE)

    def write_temporary_data_into_table(self, csv_data_file_path: str) -> None:
        clients_dataframe: DataFrame = pandas.read_csv(csv_data_file_path)

        try:
            clients_dataframe.to_sql(name=self.__temporary_table_name,
                                     con=self.__postgres_connection,
                                     if_exists='replace',
                                     index=True)
        except Exception:
            logging.error(f'Error while inserting into the table in db')
            sys.exit(constants.OutputConstants.EXIT_FAILURE)

    def validate_temporary_data(self):
        try:
            postgres_cursor = self.__postgres_connection.cursor()
            postgres_cursor.callproc(self.__validation_procedure_name)
            postgres_cursor.commit()
            postgres_cursor.close()
        except Exception as error:
            logging.error(f'There was an error while executing the validation procedure: {error}')
            sys.exit(constants.OutputConstants.EXIT_FAILURE)
