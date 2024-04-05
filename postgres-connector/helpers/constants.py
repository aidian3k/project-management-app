class OutputConstants:
    EXIT_SUCCESS = 0
    EXIT_FAILURE = 1


class FileNames:
    clients_file = "clients.csv"
    employees_file = "employees.csv"
    projects_file = "projects.csv"
    month_work = "month_work.csv"


class DatabaseConstants:
    database_name = 'postgres'


class ClientConstants:
    temporary_table_name = 'clients_temporary'
    validation_procedure_name = 'check_if_clients_data_are_okay'


class ProjectConstants:
    temporary_table_name = 'projects_temporary'
    validation_procedure_name = 'check_if_projects_data_are_okay'


class EmployeeConstants:
    temporary_table_name = 'employees_temporary'
    validation_procedure_name = 'check_if_employees_data_are_okay'


class MonthWorkConstants:
    temporary_table_name = 'month_work_temporary'
    validation_procedure_name = 'check_if_clients_data_are_okay'
