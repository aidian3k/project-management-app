# Usage of SQL and Python to build database applications
This repository shows our final project of the Usage SQL and Python to build application course at Warsaw University of Technology. 
This project aimed to create application which would process the data from csv or other text files and process them. The main purpose 
of this project was to process the data from the .csv or other files, then validate them using some procedures in database, and add
the data from files to the real tables in the database. After adding the data, the user should be able to generate the report for 
company invoices - for instance how much somebody worked on project in particular month to create invoice.

The application uses following technologies:
- Python(Pandas, Psycopg)
- PostgreSQL database

# How to run the application
Whole application is based on existance of the PostgreSQL database and files with data - for instance the data from Jira or AzureDevops. Then those files should be stored in data directory
in the python project. After that we should run the main.py script to load the data into the database with proper validation and then use the scripts from the database for creating invoices
from particular month by using function create_month_invoice(month: date).
