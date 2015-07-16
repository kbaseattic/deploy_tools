#CREATE DATABASE hsi;
USE hsi;
CREATE TABLE IF NOT EXISTS Handle (
        hid         int NOT NULL AUTO_INCREMENT,
        id          varchar(256) NOT NULL DEFAULT '',
        file_name   varchar(256),
        type        varchar(256),
        url         varchar(256),
        remote_md5  varchar(256),
        remote_sha1 varchar(256),
        created_by  varchar(256),
        creation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (hid)
); 
GRANT SELECT,INSERT,UPDATE,DELETE 
        ON hsi.*
        TO 'hsi'@'localhost'
        IDENTIFIED BY 'hsi-pass';

ALTER TABLE Handle ADD CONSTRAINT unique_id UNIQUE (id);
