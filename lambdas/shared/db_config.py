"""Reads catalog DB connection info from Lambda environment variables.

These are plain (unencrypted-in-code) Lambda env vars — the Lambda service decrypts them
before invocation with no network call from inside the function, which is what makes this
work from a private VPC subnet with no NAT Gateway and no KMS/Secrets Manager interface
endpoint. Do not switch this to the console's "encryption helpers" / in-function
`kms:Decrypt` path — that requires network access this design deliberately doesn't have.
"""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class DbConfig:
    host: str
    port: int
    name: str
    user: str
    password: str

    @property
    def postgres_dsn(self) -> str:
        return (
            f"host={self.host} port={self.port} dbname={self.name} "
            f"user={self.user} password={self.password}"
        )


def load_db_config() -> DbConfig:
    return DbConfig(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "5432")),
        name=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
    )
