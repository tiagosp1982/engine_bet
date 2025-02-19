from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository


def __init__(cls):
    pass

async def lista_tipo_jogo() -> dict:
    lista = tipo_jogo_repository.lista_tipo_jogo()
    return lista

async def lista_tipo_jogo_por_id(id_tipo_jogo:int) -> dict:
    lista = tipo_jogo_repository.lista_tipo_jogo_id(id_tipo_jogo)
    return lista

async def lista_tipo_jogo_estrutura(id_tipo_jogo:int) -> dict:
    lista = tipo_jogo_repository.busca_tipo_jogo_estrutura(id_tipo_jogo)
    return lista