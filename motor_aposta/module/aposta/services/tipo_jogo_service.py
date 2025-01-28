from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository


def __init__(cls):
    pass

async def lista_tipo_jogo() -> dict:
    lista = tipo_jogo_repository.lista_tipo_jogo()
    return lista