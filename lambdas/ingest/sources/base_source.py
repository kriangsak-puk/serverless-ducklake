from abc import ABC, abstractmethod


class BaseSource(ABC):
    """A pluggable ingest source. `ecommerce_db.py` simulates an OLTP pull by reading
    CSVs already dropped in S3; a real connector (SaaS API, live DB) implements the same
    interface — `fetch(table)` returning the number of rows landed.
    """

    @abstractmethod
    def tables(self) -> list[str]:
        ...

    @abstractmethod
    def fetch(self, table: str, dt: str) -> int:
        """Land raw data for `table` into the raw zone, partitioned by `dt`. Returns bytes landed."""
        ...
