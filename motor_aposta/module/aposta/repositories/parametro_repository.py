from motor_aposta.infrastructure.database.conector import conector
from atexit import register

class parametro_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def busca_parametro() -> dict:
        data = conector.read_data("""SELECT nm_base_url_atualizacao 
                                        FROM parametro"""
                                    )
        if (data == None):
            return None
        else:
            return data[0][0]
