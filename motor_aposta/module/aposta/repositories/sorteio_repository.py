from atexit import register
from motor_aposta.infrastructure.database.conector import conector


class sorteio_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def busca_sorteio_por_ciclo(id_tipo_jogo: int) -> dict:
        data = conector.read_data(f"""SELECT s.nr_concurso
                                             , s.nr_sorteado 
                                          FROM sorteio s
                                         WHERE s.id_tipo_jogo={id_tipo_jogo}
                                           AND s.nr_concurso >= ( select max(nr_concurso) 
                                                                    from ciclo c 
                                                                   where c.id_tipo_jogo = s.id_tipo_jogo
                                                                     and c.bt_finalizado = 1
                                                                )
                                         ORDER BY s.nr_concurso DESC
                                                , s.nr_sorteado ASC"""
                                   )
        return data

    def busca_sorteio(id_tipo_jogo: int, limit_data: int) -> dict:
        data = conector.read_data(f"""SELECT s.nr_concurso
                                             , s.nr_sorteado 
                                          FROM sorteio s
                                               inner join ( select c.nr_concurso
                                                              from concurso c
                                                             where c.id_tipo_jogo = {id_tipo_jogo}
                                                             order by c.nr_concurso desc
                                                             limit {limit_data}
                                                          ) t on t.nr_concurso = s.nr_concurso
                                         WHERE s.id_tipo_jogo={id_tipo_jogo}
                                         ORDER BY s.nr_concurso DESC
                                                , s.nr_sorteado ASC"""
                                   )
        return data

    def busca_sorteio_agrupado(id_tipo_jogo: int) -> dict:
        data = conector.read_data(f"""SELECT nr_concurso
                                          , dezenas 
                                       FROM vw_sorteio
                                      WHERE id_tipo_jogo={id_tipo_jogo} 
                                      ORDER BY nr_concurso DESC"""
                                )
        return data