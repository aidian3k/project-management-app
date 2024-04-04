do
$$
    begin
        if count(select 1 from pg_database where
                 datname = 'company_management') = 0 then
            create database company_management;
        end if;
    end;
$$;


drop procedure if exists remove_table;
create or replace procedure remove_table(remove_table text)
    language plpgsql
as
$$
begin
    if count(select 1 from information_schema.tables where
             table_name = remove_table) > 0 then
        execute format('drop table %I', remove_table);
    end if;
end;
$$;

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
    nip              text
);

call remove_table('projects_temporary');
create table projects_temporary
(
    project_name   text,
    client_name    text,
    start_date     text,
    end_date       text,
    description text
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

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM information_schema.tables
                       WHERE table_schema = 'public'
                         AND table_name = 'logs') THEN
            CREATE TABLE public.logs
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

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM information_schema.tables
                       WHERE table_schema = 'public'
                         AND table_name = 'detailed_logs') THEN
            CREATE TABLE public.detailed_logs
            (
                logs_id              INT          NOT NULL,
                detailed_description VARCHAR(300) NOT NULL,
                FOREIGN KEY (logs_id) REFERENCES logs (id)
            );
        END IF;
    END
$$;

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM information_schema.tables
                       WHERE table_schema = 'public'
                         AND table_name = 'detailed_logs') THEN
            CREATE TABLE public.detailed_logs
            (
                logs_id              INT          NOT NULL,
                detailed_description VARCHAR(100) NOT NULL,
                FOREIGN KEY (logs_id) REFERENCES logs (id)
            );
        END IF;
    END
$$;

do
$$
    begin
        if not exists (select 1
                       from information_schema.tables and table_name = 'clients' and table_schema = 'public') then
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
                       from information_schema.tables and
            table_name = 'transaction_logs' and table_schema = 'public') then
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

do
$$
    begin
        if not exists (select 1
                       from information_schema.tables and
            table_name = 'transaction_details' and table_schema = 'public') then
            create table transaction_details
            (
                transaction_id serial primary key,
                description    text not null
            );
        end if;
    end;
$$;

do
$$
    begin
        if not exists (select 1
                       from information_schema.tables and table_name = 'projects' and table_schema = 'public') then
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

do
$$
    begin
        if not exists (select 1
                       from information_schema.tables and
            table_name = 'departments' and table_schema = 'public') then
            create table departments
            (
                id   serial primary key,
                name text not null
            );
        end if;
    end
$$;

insert into departments (name)
values ('HR', 'Development', 'Finance', 'Marketing', 'Sales', 'Management');

do
$$
    begin
        if not exists (select 1
                       from information_schema.tables and
            table_name = 'employees' and table_schema = 'public') then
            create table employees
            (
                id              serial primary key,
                first_name      text    not null,
                last_name       text    not null,
                position        text    not null,
                phone_number    text    not null,
                email           text    not null,
                pesel           text    not null,
                salary_per_hour numeric not null,
                employment_date date    not null,
                foreign key (department) references departments (id),
                foreign key (project_id) references projects (id)
            );
        end if;
    end
$$;

do
$$
    begin
        if not exists (select 1
                       from information_schema.tables and
            table_name = 'month_work' and table_schema = 'public') then
            create table month_work
            (
                id           serial primary key,
                employee_id  numeric not null,
                date         date    not null,
                project_id   numeric not null,
                hours_worked numeric not null,
                foreign key (project_id) references projects (id),
                foreign key (employee_id) references employees (id)
            );
        end if;
    end
$$;

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

CREATE FUNCTION is_valid_email(email_text text)
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN email_text ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
END;
$$ LANGUAGE plpgsql;

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
        select helper_id, pt.company_name
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
        select helper_id, pt.company_name
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
                        and c.company_name = ct.client_name);
    count_helper := (select count(distinct ct.client_name)
                     from clients_temporary ct
                     where not exists (select 1
                                       from clients c
                                       where c.nip = ct.nip
                                         and c.company_name = ct.client_name);

    insert into transaction_logs(description)
    values ('Added new clients to the table with count: ' || count_helper)
    returning id into helper_id;
    insert into transaction_details(transaction_id, description)
    select helper_id, ct.client_name
    from clients_temporary ct
    where not exists (select 1
                      from clients c
                      where c.nip = ct.nip
                        and c.company_name = ct.client_name);

    return error_result;
END;
$$ LANGUAGE plpgsql;

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
    count_helper numeric;
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
    employees_count numeric;
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
    insert into employees(first_name, last_name, position, phone_number,
                          email, pesel, salary_per_hour, employment_date)


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
        select helper_id, mwt.date
        from month_work_temporary mwt
        group by mwt.date
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
end;
$$;

