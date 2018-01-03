

-- Data Guard
-- 
-- On primary
disable configuration
-- or on standby
alter database recover managed standby database cancel;

srvctl stop database -d STANDBY
startup mount

-- In Rman connected to standby
connect target /
recover database from service "PRIMARY" noredo section size 256m  using compressed backupset;

SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
	
RESTORE STANDBY CONTROLFILE FROM SERVICE PRIMARY;
 
alter database mount;

report schema

catalog start with '+PRIMARY_DATA';
SWITCH DATABASE TO COPY;

-- on the primary
ALTER SYSTEM ARCHIVE LOG CURRENT;

-- on the standby, in RMAN
RECOVER DATABASE;
ALTER DATABASE OPEN READ ONLY;

shutdown immediate
startup mount

-- On primary 
enable configuraton
-- or standby
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

-- broker possibly does everything or
-- Log files may be messed up - issue below to give it a kick and restart.
alter system set log_file_name_convert='test','test' scope=spfile;
-- you can just rm them if further problems exists and restart


