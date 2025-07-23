-- Test query for group execution
SELECT 
  current_database() as database_name,
  version() as postgres_version,
  current_timestamp as execution_time;
