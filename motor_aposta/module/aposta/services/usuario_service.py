from motor_aposta.module.aposta.dtos.usuario_dto import UsuarioDTO
from motor_aposta.module.aposta.repositories.usuario_repository import usuario_repository


def __init__(cls):
    pass

async def valida_usuario(email: str, senha: str) -> UsuarioDTO:
    usuario = usuario_repository.busca_usuario_logon(email, senha)
    return usuario
    
