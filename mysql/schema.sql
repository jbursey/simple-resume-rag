CREATE TABLE memory_entries
(
    memory_id BIGINT NOT NULL AUTO_INCREMENT,
    memory_content TEXT NOT NULL,
    PRIMARY KEY (memory_id)
) ENGINE=InnoDb;

-- Allow connections from any host ('%') or restrict to a specific host/subnet (e.g. 'localhost' or '172.%')
CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY 'P@ssWord123!';

-- Core read/write (DML) permissions on llm_memory
GRANT SELECT, INSERT, UPDATE, DELETE ON llm_memory.* TO 'app_user'@'%';

-- Optional: include if the app/migrations run DDL (creating/altering tables or indexes)
-- GRANT CREATE, ALTER, INDEX, REFERENCES ON llm_memory.* TO 'app_user'@'%';

FLUSH PRIVILEGES;