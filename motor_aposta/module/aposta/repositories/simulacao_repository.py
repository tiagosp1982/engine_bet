from atexit import register
from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.dtos.simulacao_dto import SimulacaoDto
from motor_aposta.module.aposta.factories.simulacao_factory import SimulacaoFactory


class simulacao_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def atualiza_simulacao(obj: SimulacaoDto) -> bool:
        instruction = """INSERT INTO SIMULACAO (id_simulacao, id_usuario, id_tipo_jogo, nr_concurso, tp_geracao)
                        VALUES({0},{1},{2},{3},'{4}')"""
        command = instruction.format(obj.id_simulacao, obj.id_usuario, obj.id_tipo_jogo, obj.nr_concurso, obj.tp_geracao)
        exec = conector.write_data(command)
        return exec

    def atualiza_simulacao_item(obj: dict) -> bool:
        command = "INSERT INTO SIMULACAO_ITEM (id_simulacao, id_usuario, id_tipo_jogo, nr_concurso, nr_simulado) VALUES(%s, %s, %s, %s, %s)"
        exec = conector.write_data_many(command, obj)
        return exec

    def busca_ultima_simulacao(id_tipo_jogo: int, id_usuario: int, nr_concurso_aposta: int) -> SimulacaoDto:
        data = conector.read_data(f"""SELECT MAX(id_simulacao) as id_simulacao
                                                 , id_usuario 
                                                 , id_tipo_jogo 
                                                 , nr_concurso 
                                              FROM simulacao s
                                             WHERE id_tipo_jogo = {id_tipo_jogo}
                                               AND id_usuario = {id_usuario}
                                               AND nr_concurso = {nr_concurso_aposta}
                                             GROUP BY id_usuario
                                                    , id_tipo_jogo
                                                    , nr_concurso"""
                                      )
        if (data == None or len(data) == 0):
            return None

        return SimulacaoFactory.obj(data)

    def busca_simulacao_item(id_tipo_jogo: int, id_usuario: int, nr_concurso_aposta: int) -> dict:
        data = conector.read_data(f"""SELECT id_simulacao
                                                 , nr_simulado
                                              FROM simulacao_item s
                                             WHERE id_tipo_jogo = {id_tipo_jogo}
                                               AND id_usuario = {id_usuario}
                                               AND nr_concurso = {nr_concurso_aposta}"""
                                      )
        return SimulacaoFactory.factoryItem(data)