-- Expires DuckLake snapshots older than the retention window, allowing the underlying
-- Parquet files they alone reference to be physically deleted on the next cleanup pass.
-- {older_than} is substituted by lambdas/maintain/compaction.py (e.g. now() - INTERVAL 30 DAY).
CALL ducklake_expire_snapshots('ducklake_catalog', older_than => {older_than});
