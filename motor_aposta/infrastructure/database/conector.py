import psycopg2
import psycopg2.extras
import os
from dotenv import load_dotenv


load_dotenv()


DATABASE_URL = os.getenv("DATABASE_URL")

class conector:
    def __init__(cls):
        pass
    
    def read_data(query) -> dict:
        try:
            conexao = psycopg2.connect(DATABASE_URL)

            # Criar um cursor para executar comandos SQL
            cursor = conexao.cursor()

            # Execute operações no banco de dados aqui...
            cursor.execute(query)
            list = cursor.fetchall()

            if cursor:
                cursor.close()
            if conexao:
                conexao.close()

            return list
        except Exception as e:
            print("Erro ao conectar ou operar no banco de dados1:", e)
            
    def read_data_new(query) -> dict:
        try:
            conexao = psycopg2.connect(DATABASE_URL)

            # Criar um cursor para executar comandos SQL
            cursor = conexao.cursor(cursor_factory=psycopg2.extras.DictCursor)

            # Execute operações no banco de dados aqui...
            cursor.execute(query)
            result = [dict(row) for row in cursor.fetchall()]

            if cursor:
                cursor.close()
            if conexao:
                conexao.close()

            return result
        except Exception as e:
            print("Erro ao conectar ou operar no banco de dados1:", e)

    def write_data(command) -> bool:
        try:
            # Conectar ao banco de dados
            conexao = psycopg2.connect(DATABASE_URL)

            # Criar um cursor para executar comandos SQL
            cursor = conexao.cursor()

            # Execute operações no banco de dados aqui...
            cursor.execute(command)
            conexao.commit()

            if cursor:
                cursor.close()
            if conexao:
                conexao.close()

            return True
        except Exception as e:
            print("Erro ao conectar ou operar no banco de dados2:", e)

    def write_to_csv(arquivo: str, tabela: str) -> bool:
        conexao = psycopg2.connect(DATABASE_URL)

        # Criar um cursor para executar comandos SQL
        cursor = conexao.cursor()
        
        with open(arquivo, 'r') as f:
            cursor.copy_expert(f"COPY {tabela} FROM STDIN WITH CSV", f)
            conexao.commit()
        
        if cursor:
            cursor.close()
        if conexao:
            conexao.close()

        return True
    
    def write_data_many(command, data) -> bool:
        try:
            # Conectar ao banco de dados
            conexao = psycopg2.connect(DATABASE_URL)

            # Criar um cursor para executar comandos SQL
            cursor = conexao.cursor()

            # Execute operações no banco de dados aqui...
            cursor.executemany(command, data)
            conexao.commit()

            if cursor:
                cursor.close()
            if conexao:
                conexao.close()

            return True
        except Exception as e:
            print("Erro ao conectar ou operar no banco de dados3:", e)
# from sqlalchemy import create_engine
# from sqlalchemy.ext.declarative import declarative_base
# from sqlalchemy.orm import sessionmaker

# # SQLALCHEMY_DATABASE_URL = "sqlite:///./sql_app.db"
# SQLALCHEMY_DATABASE_URL = "postgresql://postgres:F4milia_2023_@localhost/dbTarget"

# engine = create_engine(
#     SQLALCHEMY_DATABASE_URL
# )
# SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base = declarative_base()