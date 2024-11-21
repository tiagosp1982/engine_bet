from atexit import register
from engine_bet.infrastructure.database.conector import conector
from engine_bet.module.bet.dtos.simulacao_dto import SimulacaoDto
from engine_bet.module.bet.factories.simulacao_factory import SimulacaoFactory


class simulation_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def save_simulation(obj: SimulacaoDto) -> bool:
        instruction = """INSERT INTO SIMULACAO (id_simulacao, id_usuario, id_tipo_jogo, nr_concurso, tp_geracao)
                        VALUES({0},{1},{2},{3},'{4}')"""
        command = instruction.format(obj.id_simulacao, obj.id_usuario, obj.id_tipo_jogo, obj.nr_concurso, obj.tp_geracao)
        exec = conector.write_data(command)
        return exec

    def save_item_simulation(obj: dict) -> bool:
        command = "INSERT INTO SIMULACAO_ITEM (id_simulacao, id_usuario, id_tipo_jogo, nr_concurso, nr_simulado) VALUES(%s, %s, %s, %s, %s)"
        exec = conector.write_data_many(command, obj)
        return exec

    def read_last_simulation(id_tipo_jogo: int, id_usuario: int, nr_concurso_aposta: int) -> SimulacaoDto:
        simulation = conector.read_data(f"""SELECT MAX(id_simulacao) as id_simulacao
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
        if (simulation == None or len(simulation) == 0):
            return None

        return SimulacaoFactory.obj(simulation)

    def read_simulation_item(id_tipo_jogo: int, id_usuario: int, nr_concurso_aposta: int) -> dict:
        simulation = conector.read_data(f"""SELECT id_simulacao
                                                 , nr_simulado
                                              FROM simulacao_item s
                                             WHERE id_tipo_jogo = {id_tipo_jogo}
                                               AND id_usuario = {id_usuario}
                                               AND nr_concurso = {nr_concurso_aposta}"""
                                      )
        return SimulacaoFactory.factoryItem(simulation)