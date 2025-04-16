from atexit import register
from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.dtos.aposta_dto import ApostaDto
from motor_aposta.module.aposta.dtos.aposta_item_dto import ApostaItemDto


class aposta_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def atualiza_aposta(obj: ApostaDto) -> bool:
        instruction = """INSERT INTO APOSTA (id_aposta, id_usuario, id_tipo_jogo, nr_concurso, dt_aposta)
                        VALUES({0},{1},{2},{3},'{4}')"""
        command = instruction.format(obj.id_aposta, obj.id_usuario, obj.id_tipo_jogo, obj.nr_concurso, obj.dt_aposta)
        exec = conector.write_data(command)
        return exec

    def atualiza_aposta_item(obj: dict) -> bool:
        command = """INSERT INTO APOSTA_ITEM (id_aposta, id_usuario, id_tipo_jogo, nr_concurso, nr_aposta)
                        VALUES(%s, %s, %s, %s, %s)"""
        exec = conector.write_data_many(command, obj)
        return exec

    def busca_ultima_aposta(id_tipo_jogo: int, id_usuario: int, nr_concurso_aposta: int) -> ApostaDto:
        data = conector.read_data_new(f"""SELECT COALESCE(MAX(id_aposta),1) as id_aposta
                                                 , id_usuario 
                                                 , id_tipo_jogo 
                                                 , nr_concurso 
                                              FROM aposta a
                                             WHERE id_tipo_jogo = {id_tipo_jogo}
                                               AND id_usuario = {id_usuario}
                                               AND nr_concurso = {nr_concurso_aposta}
                                             GROUP BY id_usuario
                                                    , id_tipo_jogo
                                                    , nr_concurso"""
                                      )
        if (data == None or len(data) == 0):
            return None

        return [ApostaDto(**d) for d in data]