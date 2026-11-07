create role inspector with login password 'NetoSQL2025';

grant all privileges on schema ufimtsev_food to inspector;
grant all privileges on schema exts to inspector;

grant all privileges on all tables in schema ufimtsev_food to inspector;