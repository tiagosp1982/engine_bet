from atexit import register
from engine_bet.infrastructure.database.conector import conector


class raffle_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def read_raffle_by_cicle(id_type_bet: int) -> dict:
        raffle = conector.read_data(f"""SELECT s.nr_concurso
                                             , s.nr_sorteado 
                                          FROM sorteio s
                                         WHERE s.id_tipo_jogo={id_type_bet}
                                           AND s.nr_concurso >= ( select max(nr_concurso) 
                                                                    from ciclo c 
                                                                   where c.id_tipo_jogo = s.id_tipo_jogo
                                                                     and c.bt_finalizado = 1
                                                                )
                                         ORDER BY s.nr_concurso DESC
                                                , s.nr_sorteado ASC"""
                                   )
        return raffle

    def read_raffle(id_type_bet: int, limit_data: int) -> dict:
        raffle = conector.read_data(f"""SELECT s.nr_concurso
                                             , s.nr_sorteado 
                                          FROM sorteio s
                                               inner join ( select c.nr_concurso
                                                              from concurso c
                                                             where c.id_tipo_jogo = {id_type_bet}
                                                             order by c.nr_concurso desc
                                                             limit {limit_data}
                                                          ) t on t.nr_concurso = s.nr_concurso
                                         WHERE s.id_tipo_jogo={id_type_bet}
                                         ORDER BY s.nr_concurso DESC
                                                , s.nr_sorteado ASC"""
                                   )
        return raffle