CREATE TABLE departments (
    department_id NUMBER PRIMARY KEY,
    department_name VARCHAR2(100),
    location_id NUMBER
);

CREATE TABLE locations (
    location_id NUMBER PRIMARY KEY,
    city VARCHAR2(100)
);

CREATE TABLE employees (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(100),
    last_name VARCHAR2(100),
    department_id NUMBER,
    salary NUMBER,
    CONSTRAINT fk_department FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

INSERT INTO locations (location_id, city) VALUES (1, 'New York');
INSERT INTO locations (location_id, city) VALUES (2, 'Los Angeles');

INSERT INTO departments (department_id, department_name, location_id) VALUES (10, 'Finance', 1);
INSERT INTO departments (department_id, department_name, location_id) VALUES (20, 'HR', 2);

INSERT INTO employees (employee_id, first_name, last_name, department_id, salary) VALUES (1, 'John', 'Doe', 10, 6000);
INSERT INTO employees (employee_id, first_name, last_name, department_id, salary) VALUES (2, 'Jane', 'Smith', 10, 7000);
INSERT INTO employees (employee_id, first_name, last_name, department_id, salary) VALUES (3, 'Alice', 'Johnson', 20, 4000);