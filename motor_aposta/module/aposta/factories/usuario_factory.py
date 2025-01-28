from motor_aposta.module.aposta.dtos.usuario_dto import UsuarioDTO


class UsuarioFactory():
    def ConverterDto(obj) -> dict:
        return UsuarioDTO(id_usuario=obj[0][0],
                            nm_usuario=obj[0][1],
                            ds_email=obj[0][2],
                            ds_hashsenha=obj[0][3],
                            dt_nascimento=obj[0][4],
                            dt_cadastro=obj[0][5], 
                            ds_numero_celular=obj[0][6])