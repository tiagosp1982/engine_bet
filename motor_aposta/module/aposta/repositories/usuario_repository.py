from atexit import register
from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.dtos.usuario_dto import UsuarioDTO
from motor_aposta.module.aposta.factories.usuario_factory import UsuarioFactory


class usuario_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def busca_usuario_logon(_ds_email: str, _ds_senha: str) -> UsuarioDTO:
        data = conector.read_data(f"""SELECT id_usuario
                                           , nm_usuario
                                           , ds_email
                                           , ds_hashsenha
                                           , dt_nascimento
                                           , dt_cadastro
                                           , ds_numero_celular
                                        FROM usuario
                                       WHERE ds_email = '{_ds_email}'
                                         AND ds_hashsenha = '{_ds_senha}'"""
                                )
        if (data == None or len(data) == 0):
            return None

        return UsuarioFactory.ConverterDto(data)