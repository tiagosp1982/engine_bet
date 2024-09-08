from engine_bet.infrastructure.database.conector import conector
from atexit import register

class parameter_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def read_parameter() -> dict:
        param = conector.read_data("SELECT nm_base_url_atualizacao FROM parametro")
        if (param == None):
            return None
        else:
            return param[0][0]
