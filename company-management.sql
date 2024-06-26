/* creating basic procedure for removing the table from the database */
drop procedure if exists remove_table;
create or replace procedure remove_table(remove_table text)
    language plpgsql
as
$$
declare
    count numeric := (select count(*)
                      from information_schema.tables
                      where table_name = remove_table);
begin
    if count > 0 then
        execute format('drop table %I', remove_table);
    end if;
end;
$$;

/* creating temporary tables for storing the data */
/* right now, we need 4 files for handling - clients, projects, employees and month_work */

call remove_table('clients_temporary');
create table clients_temporary
(
    client_name      text,
    street           text,
    address          text,
    city             text,
    postal_code      text,
    vat_rate_percent text,
    phone            text,
    email            text,
    nip              text,
    country          text
);

call remove_table('projects_temporary');
create table projects_temporary
(
    project_name text,
    client_name  text,
    start_date   text,
    end_date     text,
    description  text
);

call remove_table('employees_temporary');
create table employees_temporary
(
    first_name      text,
    last_name       text,
    position        text,
    phone_number    text,
    department      text,
    email           text,
    pesel           text,
    salary_per_hour text,
    employment_date text
);

call remove_table('month_work_temporary');
create table month_work_temporary
(
    pesel        text,
    date         text,
    project_name text,
    hours_worked text
);

/* creating tables for storing logs during the validation
it is used for storing errors encountered during the validation process of temporary tables
in this table ony the small description and username, timestamp is stored */
DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM information_schema.tables
                       WHERE table_schema = 'public'
                         AND table_name = 'logs') THEN
            CREATE TABLE logs
            (
                id          SERIAL PRIMARY KEY,
                description text      NOT NULL,
                timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                username    text      NOT NULL DEFAULT current_user,
                hostname    text      NOT NULL DEFAULT inet_client_addr()
            );
        END IF;
    END
$$;

/* This table is used for specific detailed_logs - after adding a record
   into the logs table - the data that is wrong is written into this database
   with id = [inserted_log]
*/
DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM information_schema.tables
                       WHERE table_schema = 'public'
                         AND table_name = 'detailed_logs') THEN
            CREATE TABLE detailed_logs
            (
                logs_id              INT          NOT NULL,
                detailed_description VARCHAR(300) NOT NULL,
                FOREIGN KEY (logs_id) REFERENCES logs (id)
            );
        END IF;
    END
$$;

/* also I am creating similar tables for storing the transaction data,
therefore this table contains almost the same data as logs but is storing
the information about the inserts to particular tables - for instance insertes to real client table
*/
do
$$
    begin
        if not exists (select 1
                       from information_schema.tables
                       where table_name = 'transaction_logs'
                         and table_schema = 'public') then
            create table transaction_logs
            (
                id          serial primary key,
                description text      not null,
                timestamp   timestamp not null default current_timestamp,
                username    text      not null default current_user,
                hostname    text      not null default inet_client_addr()
            );
        end if;
    end;
$$;

/* this table - similar as detailed_logs is for storing detailed_information
   about the record that was stored in the database - it has transaction_id
   of inserted transaction and description which contains the inserted records ids
 */
do
$$
    begin
        if not exists (select 1
                       from information_schema.tables
                       where table_name = 'transaction_details'
                         and table_schema = 'public') then
            create table transaction_details
            (
                transaction_id serial primary key,
                description    text not null
            );
        end if;
    end;
$$;

/* then creating tables in which real data will be stored
firstly creating clients, projects, employees and month_work
*/
do
$$
    begin
        if not exists (select 1
                       from information_schema.tables
                       where table_name = 'clients'
                         and table_schema = 'public') then
            create table clients
            (
                id               serial primary key,
                client_name      text    not null,
                street           text    not null,
                address          text    not null,
                city             text    not null,
                postal_code      text    not null,
                vat_rate_percent numeric not null,
                phone            text    not null,
                email            text    not null,
                nip              text    not null
            );
        end if;
    end;
$$;

do
$$
    begin
        if not exists (select 1
                       from information_schema.tables
                       where table_name = 'projects'
                         and table_schema = 'public') then
            create table projects
            (
                id           serial primary key,
                project_name text not null,
                start_date   date not null,
                end_date     date not null,
                description  text not null,
                client_id    int  not null,
                foreign key (client_id) references clients (id)
            );
        end if;
    end
$$;

/* departments table is stored in the database and is maintained by the company
   the data in here is inserted by some admin of system and in employees
   file there should not exist departments that does not exist in this file
 */
do
$$
    begin
        if not exists (select 1
                       from information_schema.tables
                       where table_name = 'departments'
                         and table_schema = 'public') then
            create table departments
            (
                id   serial primary key,
                name text not null
            );
        end if;
    end
$$;

/* inserting some real data about the departments in the company */
insert into departments (name)
values ('HR'),
       ('Development'),
       ('Finance'),
       ('Marketing'),
       ('Sales'),
       ('Management');

/* creating the employees table which is connected to department table */
do
$$
    begin
        if not exists (select 1
                       from information_schema.tables
                       where table_name = 'employees'
                         and table_schema = 'public') then
            create table employees
            (
                id              serial primary key,
                first_name      text    not null,
                department_id   integer not null,
                last_name       text    not null,
                position        text    not null,
                phone_number    text    not null,
                email           text    not null,
                pesel           text    not null,
                salary_per_hour numeric not null,
                employment_date date    not null,
                foreign key (department_id) references departments (id)
            );
        end if;
    end
$$;

/* month_work is the main table of the application - it stores the data about
   hours_worked by every person in the company and the project they worked during
   this time. It has connection to the employee table and project table.
 */
do
$$
    begin
        if not exists (select 1
                       from information_schema.tables
                       where table_name = 'month_work'
                         and table_schema = 'public') then
            create table month_work
            (
                id           serial primary key,
                employee_id  integer not null,
                date         date    not null,
                project_id   integer not null,
                hours_worked numeric not null,
                foreign key (project_id) references projects (id),
                foreign key (employee_id) references employees (id)
            );
        end if;
    end
$$;

/* creating function which will transform the text to numeric data
   while importing the data into real tables
 */
CREATE OR REPLACE FUNCTION textToNumeric(txt VARCHAR(20))
    RETURNS NUMERIC AS
$$
DECLARE
    result NUMERIC;
BEGIN
    txt := REPLACE(txt, ' ', '');

    IF txt LIKE '%,%' THEN
        txt := REPLACE(txt, ',', '');
    ELSIF txt LIKE '%.%' THEN
        txt := REPLACE(txt, '.', '');
    END IF;

    txt := REPLACE(txt, ',', '.');

    result := txt::NUMERIC;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

/* testing the function
   select textToNumeric(12) = 12:numeric
   select textToNumeric(39.9) = 39.9: numeric
 */

/* similar like other table - this function is used for transforming the date
   from text in temporary tables to date object in postgresql for casting purposes
 */
CREATE OR REPLACE FUNCTION textToDate(txt text)
    RETURNS TIMESTAMP AS
$$
DECLARE
    result TIMESTAMP;
BEGIN
    IF txt ~ '^\d{8}$' THEN
        result := TO_TIMESTAMP(txt, 'YYYYMMDD');
    ELSE
        txt := REPLACE(txt, '-', '.');
        txt := REPLACE(txt, '/', '.');

        IF txt ~ '^\d{4}.\d{2}.\d{2}' THEN
            result := TO_TIMESTAMP(txt, 'YYYY.MM.DD');
        ELSE
            result := TO_TIMESTAMP(txt, 'DD.MM.YYYY');
        END IF;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

/* testing this function
   select textToDate('2024-01-01')=2024-01-01 01:00:00.0
   select textToDate('20240101')=2024-01-01 00:00:00.000000
 */

/* this function is used for checking the validity of the email and is used in validation */
CREATE FUNCTION is_valid_email(email_text text)
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN email_text ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
END;
$$ LANGUAGE plpgsql;

/* testing the function
   select is_valid_email('adrian@')=False
   select is_valid_email('adrian@wp.pl')=True
 */

/* then we have validation of the clients temporary table we check following things:
1. Checking if clients table has some records - if 0 throw an exception
2. Checking by nip the client distinct - if there are companies with the same nip number - throw an exception
3. Checking vat_rate_company - if the vat rate is < 0 or > 100 percent - throw an exception
4. Checking for email validity - if there are some invalid emails - throw an exception
------------
If everything is correct - insert the data into the table and then if transaction is correct
store the information about the data in transaction_logs_table
*/
CREATE OR REPLACE FUNCTION check_if_clients_data_are_okay()
    RETURNS numeric AS
$$
DECLARE
    error_result           numeric := 0;
    clients_count          numeric := (select count(*)
                                       from clients_temporary);
    distinct_clients_names numeric := (select count(distinct nip)
                                       from clients_temporary);
    vat_rates_over_100     numeric := (select count(*)
                                       from clients_temporary
                                       where textToNumeric(vat_rate_percent) > 100
                                          or textToNumeric(vat_rate_percent) < 0);
    error_message          text    := 'There is an error in clients data: ';
    invalid_emails         numeric := (select count(*)
                                       from clients_temporary
                                       where not is_valid_email(email));
    helper_id              numeric;
    count_helper           numeric;
BEGIN
    if clients_count = 0 then
        error_message := error_message ||
                         'No clients were found in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;
        insert into detailed_logs (logs_id, detailed_description)
        values (helper_id, 'No clients were found in the temporary table!');

        error_result := 1;

        return error_result;
    end if;

    if distinct_clients_names > clients_count then
        error_message := error_message ||
                         'There are clients with the same name in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs(logs_id, detailed_description)
        select helper_id, pt.client_name
        from clients_temporary pt
        group by pt.client_name
        having count(*) > 1;

        error_result := 1;

        return error_result;
    end if;

    if vat_rates_over_100 > 0 then
        error_message := error_message ||
                         'There are clients with vat rate over 100% or below 0% in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs(logs_id, detailed_description)
        select helper_id, pt.client_name
        from clients_temporary pt
        where textToNumeric(pt.vat_rate_percent) > 100
           or textToNumeric(pt.vat_rate_percent) < 0;

        error_result := 1;

        return error_result;
    end if;

    if invalid_emails > 0 then
        error_message := error_message ||
                         'There are clients with invalid emails in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs(logs_id, detailed_description)
        select helper_id, pt.client_name
        from clients_temporary pt
        where not is_valid_email(pt.email);

        error_result := 1;

        return error_result;
    end if;

    /* Adding new clients to the table */
    insert into clients(client_name, street, address, city, postal_code,
                        vat_rate_percent, phone, email, nip)
    select distinct ct.client_name,
                    ct.street,
                    ct.address,
                    ct.city,
                    ct.postal_code,
                    textToNumeric(ct.vat_rate_percent),
                    ct.phone,
                    ct.email,
                    ct.nip
    from clients_temporary ct
    where not exists (select 1
                      from clients c
                      where c.nip = ct.nip
                        and c.client_name = ct.client_name);
    count_helper := (select count(distinct ct.client_name)
                     from clients_temporary ct
                     where not exists (select 1
                                       from clients c
                                       where c.nip = ct.nip
                                         and c.client_name = ct.client_name));

    insert into transaction_logs(description)
    values ('Added new clients to the table with count: ' || count_helper)
    returning id into helper_id;
    insert into transaction_details(transaction_id, description)
    select helper_id, ct.client_name
    from clients_temporary ct
    where not exists (select 1
                      from clients c
                      where c.nip = ct.nip
                        and c.client_name = ct.client_name);

    return error_result;
END;
$$ LANGUAGE plpgsql;

/* running the function
   select check_if_clients_data_are_okay() = if okay 0 - if not 0
 */

/* Then we have projects_validation which contains of following checking queries:
1. Firstly checking if even there is some data in the file - if not - throw an exception
2. Checking if there is a project which has starting_date > now(). If so throw an exception
3. Checking if projects are matching clients - checking if in temporary or clients table there is
client with the same name as in clients table
4. Checking if there is some duplication of the projects in the temporary table - if so throw an exception
--------------------------
If this validation passes - then insert the data into the real projects_table
 */
create or replace function check_if_projects_data_are_okay()
    returns numeric as
$$
declare
    error_result                        numeric := 0;
    helper_id                           numeric;
    error_message                       text    := 'There is an error in projects data: ';
    existing_projects_out_of_date_range numeric := (select count(*)
                                                    from projects_temporary
                                                    where (textToDate(start_date) > textToDate(end_date))
                                                       or (textToDate(start_date) < now()));
    projects_matching_clients           numeric := (select count(*)
                                                    from projects_temporary pt
                                                             left join clients_temporary ct
                                                                       on pt.client_name = ct.client_name
                                                    where ct.client_name is null
                                                       or pt.client_name is null);
    duplicated_projects                 numeric := (select count(*)
                                                    from projects_temporary
                                                    group by project_name
                                                    having count(*) > 1);
    count_helper                        numeric;
begin
    if (select count(*) from projects_temporary) = 0 then
        error_message := error_message ||
                         'No projects were found in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        values (helper_id, 'No projects were found in the temporary table!');

        error_result := 1;
        return error_result;
    end if;

    if existing_projects_out_of_date_range > 0 then
        error_message := error_message ||
                         'There are projects with start date later than end date or start date earlier than now in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, pt.project_name
        from projects_temporary pt
        where (textToDate(pt.start_date) > textToDate(pt.end_date))
           or (textToDate(pt.start_date) < now());

        error_result := 1;
        return error_result;
    end if;

    if projects_matching_clients > 0 then
        error_message := error_message ||
                         'There are projects with clients that do not exist in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, pt.project_name
        from projects_temporary pt
                 left join clients_temporary ct
                           on pt.client_name = ct.client_name
        where ct.client_name is null
           or pt.client_name is null;

        error_result := 1;
        return error_result;
    end if;

    if duplicated_projects > 0 then
        error_message := error_message ||
                         'There are duplicated projects in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, pt.project_name
        from projects_temporary pt
        group by pt.project_name
        having count(*) > 1;

        error_result := 1;
        return error_result;
    end if;

    /* inserting the data into the projects table */
    insert into projects(project_name, start_date, end_date, description,
                         client_id)
    select distinct pt.project_name,
                    textToDate(pt.start_date),
                    textToDate(pt.end_date),
                    'No description',
                    c.id
    from projects_temporary pt
             join clients c on pt.client_name = c.client_name
    where not exists (select 1
                      from projects p
                      where p.project_name = pt.project_name
                        and p.client_id = c.id);

    count_helper := (select count(distinct pt.project_name)
                     from projects_temporary pt
                              join clients c on pt.client_name = c.client_name
                     where not exists (select 1
                                       from projects p
                                       where p.project_name = pt.project_name
                                         and p.client_id = c.id));

    insert into transaction_logs(description)
    values ('Added new clients to the projects with count: ' || count_helper)
    returning id into helper_id;

    insert into transaction_details(transaction_id, description)
    select helper_id, pt.project_name
    from projects_temporary pt
             join clients c on pt.client_name = c.client_name
    where not exists (select 1
                      from projects p
                      where p.project_name = pt.project_name
                        and p.client_id = c.id);

end;
$$;

/* Then checking if the employees data are correct by following things:
1. Checking if there are duplicated_pesels in the file which has to be unique - if so - throw an exception
2. Checking if the employee is in the department which is stored in the database - if not - throw an exception
3. Checking if there are 0 records in the employees table - if so - throw an exception
--------------
If those validations passes - the employees data is inserted into the real database table
 */
create function check_if_employees_data_are_okay()
    returns numeric as
$$
declare
    error_result                          numeric := 0;
    helper_id                             numeric;
    error_message                         text    := 'There is an error in employees data: ';
    duplicated_pesels                     numeric := (select count(*)
                                                      from employees_temporary
                                                      group by pesel
                                                      having count(*) > 1);
    department_not_in_list_of_departments numeric := (select count(*)
                                                      from employees_temporary et
                                                               left join departments d
                                                                         on et.department = d.name
                                                      where d.name is null);
    count_helper                          numeric;
begin
    if (select count(*) from employees_temporary) = 0 then
        error_message := error_message ||
                         'No employees were found in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        values (helper_id, 'No employees were found in the temporary table!');

        error_result := 1;
        return error_result;
    end if;

    if duplicated_pesels > 0 then
        error_message := error_message ||
                         'There are employees with duplicated pesels in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, et.pesel
        from employees_temporary et
        group by et.pesel
        having count(*) > 1;

        error_result := 1;
        return error_result;
    end if;

    if department_not_in_list_of_departments > 0 then
        error_message := error_message ||
                         'There are employees with departments that do not exist in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, et.first_name || ' ' || et.last_name
        from employees_temporary et
                 left join departments d
                           on et.department = d.name
        where d.name is null;

        error_result := 1;
        return error_result;
    end if;

    /* inserting the employees into the projects employees table */
    insert into employees(pesel, last_name, position, phone_number,
                          email, first_name, salary_per_hour, employment_date)
    select distinct et.pesel,
                    et.last_name,
                    et.position,
                    et.phone_number,
                    et.email,
                    et.first_name,
                    textToNumeric(et.salary_per_hour),
                    textToDate(et.employment_date)
    from employees_temporary et
    where not exists(select 1
                     from employees e
                     where e.pesel = et.pesel
                       and e.first_name = et.first_name
                       and et.last_name = e.last_name);


    count_helper := (select count(distinct et.pesel)
                     from employees_temporary et
                     where not exists(select 1
                                      from employees e
                                      where e.pesel = et.pesel
                                        and e.first_name = et.first_name
                                        and et.last_name = e.last_name);

    insert into transaction_logs(description)
    values ('Added new employees to the projects with count: ' || count_helper)
    returning id into helper_id;

    insert into transaction_details(transaction_id, description)
    select helper_id, et.pesel
    from employees_temporary et
    where not exists(select 1
                     from employees e
                     where e.pesel = et.pesel
                       and e.first_name = et.first_name
                       and et.last_name = e.last_name);
end;
$$;

/* Lastly - we are checking the data from month_work:
1. Checking if the existing_employees_that_not_in file - if so - throw an exception
2. Checking if there are days from the future in month_work - if so - throw an exception
3. Checking if all days are from the same month - if so - throw an exception
4. Checking if projects are in the projects table already - if not - throw an exception
5. Checking if the  hours_worked in single day exceed 24 hours - if so - throw an exception
---------------------
If the data is correct - inserting the data into the month_work_table
 */
create function check_if_month_work_data_are_okay()
    returns numeric as
$$
declare
    error_result                         numeric := 0;
    helper_id                            numeric;
    error_message                        text    := 'There is an error in month_work data: ';
    existing_employees_that_not_in_file  numeric := (select count(*)
                                                     from employees e
                                                              left join month_work_temporary mwt
                                                                        on e.pesel = mwt.pesel
                                                     where mwt.pesel is null);
    duplicated_days                      numeric := (select count(*)
                                                     from month_work_temporary
                                                     group by date
                                                     having count(*) > 1);
    days_from_future                     numeric := (select count(*)
                                                     from month_work_temporary
                                                     where textToDate(date) > now());
    all_days_are_not_from_the_same_month numeric := (select count(*)
                                                     from month_work_temporary
                                                     group by extract(month from textToDate(date)));
    project_that_is_not_in_projects      numeric := (select count(*)
                                                     from month_work_temporary mwt
                                                              left join projects p
                                                                        on mwt.project_name = p.project_name
                                                     where p.project_name is null);
    count_helper                         numeric;
    hours_worked_more_than_24            numeric := (select count(*)
                                                     from month_work_temporary
                                                     where textToNumeric(hours_worked) > 24);
begin
    if (select count(*) from month_work_temporary) = 0 then
        error_message := error_message ||
                         'No month work data were found in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        values (helper_id,
                'No month work data were found in the temporary table!');

        error_result := 1;
        return error_result;
    end if;

    if existing_employees_that_not_in_file > 0 then
        error_message := error_message ||
                         'There are employees that do not exist in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, e.first_name || ' ' || e.last_name
        from employees e
                 left join month_work_temporary mwt
                           on e.pesel = mwt.pesel
        where mwt.pesel is null;

        error_result := 1;
        return error_result;
    end if;

    if duplicated_days > 0 then
        error_message := error_message ||
                         'There are duplicated days in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, mwt.date || mwt.pesel
        from month_work_temporary mwt
        group by (mwt.pesel, mwt.date)
        having count(*) > 1;

        error_result := 1;
        return error_result;
    end if;

    if days_from_future > 0 then
        error_message := error_message ||
                         'There are days from the future in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, mwt.date
        from month_work_temporary mwt
        where textToDate(mwt.date) > now();

        error_result := 1;
        return error_result;
    end if;

    if days_not_from_the_same_month > 0 then
        error_message := error_message ||
                         'There are days that are not from the same month in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, mwt.date
        from month_work_temporary mwt
        where extract(month from textToDate(mwt.date)) !=
              extract(month from now());

        error_result := 1;
        return error_result;
    end if;

    if all_days_are_not_from_the_same_month <> 1 then
        error_message := error_message ||
                         'There are days that are not from the same month in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, mwt.date
        from month_work_temporary mwt
        group by extract(month from textToDate(mwt.date))
        having count(*) > 1;

        error_result := 1;
        return error_result;
    end if;

    if project_that_is_not_in_projects > 0 then
        error_message := error_message ||
                         'There are projects that do not exist in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, mwt.project_name
        from month_work_temporary mwt
                 left join projects p
                           on mwt.project_name = p.project_name
        where p.project_name is null;

        error_result := 1;
        return error_result;
    end if;

    if hours_worked_more_than_24 > 0 then
        error_message := error_message ||
                         'There are hours worked that are more than 24 in the temporary table!';
        insert into logs (description)
        values (error_message)
        returning id into helper_id;

        insert into detailed_logs (logs_id, detailed_description)
        select helper_id, mwt.hours_worked
        from month_work_temporary mwt
        where textToNumeric(mwt.hours_worked) > 24;

        error_result := 1;
        return error_result;
    end if;

    /* inserting the data into the month_work table */
    insert into month_work(employee_id, date, project_id, hours_worked)
    select e.id, textToDate(mwt.date), p.id, textToNumeric(mwt.hours_worked)
    from month_work_temporary mwt
             join employees e on mwt.pesel = e.pesel
             join projects p on mwt.project_name = p.project_name
    where not exists (select 1
                      from month_work mw
                      where mw.employee_id = e.id
                        and mw.date = textToDate(mwt.date)
                        and mw.project_id = p.id);

    count_helper := (select count(distinct mwt.date)
                     from month_work_temporary mwt
                              join employees e on mwt.pesel = e.pesel
                              join projects p on mwt.project_name = p.project_name
                     where not exists (select 1
                                       from month_work mw
                                       where mw.employee_id = e.id
                                         and mw.date = textToDate(mwt.date)
                                         and mw.project_id = p.id));
    insert into transaction_logs(description)
    values ('Added new month work data to the table with count: ' ||
            count_helper)
    returning id into helper_id;

    insert into transaction_details(transaction_id, description)
    select helper_id, '' || mwt.date || ' ' || mwt.pesel
    from month_work_temporary mwt
             join employees e on mwt.pesel = e.pesel
             join projects p on mwt.project_name = p.project_name
    where not exists (select 1
                      from month_work mw
                      where mw.employee_id = e.id
                        and mw.date = textToDate(mwt.date)
                        and mw.project_id = p.id);
end
$$;

/* creating the table for storing current raport schema function to generate reports standard in xml */
/* this table is used for possible new types of the raport standard and inserting some possible new data to that table*/
call remove_table('raport_schemas');
create table raport_schemas
(
    type               text,
    from_date          date,
    sql_procedure_name text,
    primary key (type, from_date)
);
insert into raport_schemas (type, from_date, sql_procedure_name)
values ('standard', '2024-04-01', 'standard_month_raport2'),
       ('standard', '2023-04-01', 'standard_month_raport1'),
       ('standard', '2022-04-01', 'standard_month_raport0');

/* creating some functions for the raport generating from the past and right now */
create or replace function standard_month_raport0(year_month nchar(6))
    returns xml as
$$
begin
end;
$$ language plpgsql;

create or replace function standard_month_raport1(year_month nchar(6))
    returns xml as
$$
begin
end;
$$ language plpgsql;

create or replace function standard_month_raport2(year_month nchar(6))
    returns xml as
$$
begin
end;
$$ language plpgsql;

/* This function is used for generating the report based on some wanted_type
   and also wanted_from date. It checks the procedure wanted_type and wanted_from
   date - fetches the procedure_name from the table and then executing the procedure
 */
create or replace procedure generate_report(wanted_type text, wanted_from_date date)
    language plpgsql
as
$$
declare
    created_sql   text;
    function_name text;
    found_month   text;

begin
    found_month := (select max(from_date)
                    from raport_schemas rs
                    where rs.type = wanted_type
                      and rs.from_date <= wanted_from_date);

    if found_month is null then
        raise exception 'There is no schema for the given date!';
        return -1;
    end if;

    function_name := (select sql_procedure_name
                      from raport_schemas rs
                      where rs.type = wanted_type
                        and rs.from_date = found_month);
    created_sql := 'call ' || function_name || '(' || wanted_from_date || ')';

    execute created_sql;
end ;
$$;

/* This is procedure for generating the standard_month_report based on year_month
   This is used for firstly - fetching all the data from year_month_table and then
   generating the report in xml for having the aggregation of the project from one month
   and all the costs for particular project
 */
create or replace procedure standard_month_report(year_month nchar(6)) as
$$
begin
    SELECT XMLELEMENT(
                   NAME "monthly_work_report",
                   XMLATTRIBUTES('month_report_for_' || year_month AS "month"),
                   (SELECT XMLAGG(
                                   XMLELEMENT(
                                           NAME "project",
                                           XMLATTRIBUTES(p.project_name AS
                                           "name"),
                                           (SELECT XMLAGG(
                                                           XMLELEMENT(NAME
                                                                      "work_entry",
                                                                      XMLFOREST(
                                                                              e.first_name as
                                                                              "first_name",
                                                                              e.last_name as
                                                                              "last_name",
                                                                              e.position as
                                                                              "position",
                                                                              e.email as
                                                                              "email",
                                                                              (select sum(w.hour_worked)) as
                                                                              "hours_worked_in_month",
                                                                              (select sum(w.hour_worked * e.salary_per_hour)) as
                                                                              "salary_in_month_brutto",
                                                                              (select sum(w.hour_worked * e.salary_per_hour * 0.77)) as
                                                                              "salary_in_month_netto"
                                                                      )
                                                           )
                                                   ))
                                           FROM month_work w
                                           join employees e on
                                           e.id = w.employee_id
                                           where w.project_id = p.id
                                               and w.date >=
                                                   DATE_TRUNC('month', textToDate(year_month))
                                               AND w.date < DATE_TRUNC('month',
                                                                       textToDate(year_month) +
                                                                       INTERVAL '1 month'))
                           ))
           )
    FROM (select distinct project_name
          FROM projects p
          where p.end_date >= textToDate(year_month)) p)
           ) AS xml_result;

end;
$$
    language plpgsql;

/* sample run of the function
   select standard_month_report('202401')
   output:

   <monthly_work_report month="month_report_for_202401">
    <project name="Project A">
        <work_entry>
            <first_name>John</first_name>
            <last_name>Doe</last_name>
            <position>Developer</position>
            <email>john.doe@example.com</email>
            <hours_worked_in_month>120</hours_worked_in_month>
            <salary_in_month_brutto>6000.00</salary_in_month_brutto>
            <salary_in_month_netto>4620.00</salary_in_month_netto>
        </work_entry>
        <!-- More work_entry elements for other employees working on Project A -->
    </project>
    <project name="Project B">
    </project>
    <project name="Project C">
    </project>
    <project name="Project D"">
    </project>
</monthly_work_report>
 */