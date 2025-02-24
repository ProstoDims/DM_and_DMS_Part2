CREATE USER dev_schema IDENTIFIED BY dev_password;
CREATE USER prod_schema IDENTIFIED BY prod_password;
GRANT CONNECT, RESOURCE TO dev_schema, prod_schema;


ALTER SESSION SET CURRENT_SCHEMA = dev_schema;

CREATE TABLE dev_table1 (
    id NUMBER,
    name VARCHAR2(100)
);
CREATE TABLE dev_table2 (
    id NUMBER,
    description VARCHAR2(200)
);


ALTER SESSION SET CURRENT_SCHEMA = prod_schema;

CREATE TABLE prod_table1 (
    id NUMBER,
    name VARCHAR2(100)
);
CREATE TABLE prod_table3 (
    id NUMBER,
    details VARCHAR2(200)
);