USE hsi;
CREATE TABLE IF NOT EXISTS Handle (
        id              varchar(256) NOT NULL DEFAULT '',
        file_name     varchar(256),
        type            varchar(256),
        url             varchar(256),
        remote_md5      varchar(256),
        remote_sha1     varchar(256),
        created_by      varchar(256),
        creation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
);
