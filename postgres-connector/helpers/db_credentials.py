from constants import DatabaseConstants


class DatabaseCredentials:
    def __init__(self, ip_address: str = "localhost", port: int = 5432, username: str = "root", password: str = "root"):
        self.ip_address = ip_address
        self.port = port
        self.username = username
        self.password = password
        self.database_name = DatabaseConstants.database_name

    def __str__(self):
        return f'Connection to database with ip_address: {self.ip_address}, port: {self}, username: {self.username}'
