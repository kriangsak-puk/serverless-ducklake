-- Merges small Parquet files produced by repeated small INSERTs into fewer, larger files.
-- Run against each DuckLake table; {table} is substituted by lambdas/maintain/compaction.py.
CALL ducklake_merge_adjacent_files('ducklake_catalog', '{table}');
