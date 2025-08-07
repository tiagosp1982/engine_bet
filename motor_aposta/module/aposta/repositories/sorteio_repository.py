from atexit import register
from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory
from motor_aposta.module.aposta.dtos.sorteio_dto import SorteadoDto, SorteioMolduraCentroDTO


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

    def lista_sorteio(_id_tipo_jogo: int) -> dict:
        data = conector.read_data(f"""SELECT s.nr_concurso
                                           , s.nr_sorteado 
                                        FROM sorteio s
                                       WHERE s.id_tipo_jogo={_id_tipo_jogo}
                                       ORDER BY s.nr_concurso DESC
                                              , s.nr_sorteado ASC"""
                                   )
        if (data == None):
            return None
        
        return SorteioFactory.ConverterDto(_id_tipo_jogo, data)

    def lista_sorteio_combinacao(_id_tipo_jogo: int, _nr_qtde_dezena: int) -> dict:
        data = conector.read_data(f"""SELECT s.nr_concurso
                                           , s.nr_sorteado 
                                        FROM sorteio s
                                       WHERE s.id_tipo_jogo={_id_tipo_jogo}
                                         AND NOT EXISTS ( SELECT 1
                                                            FROM combinacao_sorteio cs
                                                           WHERE cs.id_tipo_jogo = s.id_tipo_jogo
                                                             AND cs.nr_concurso = s.nr_concurso
                                                             AND cs.nr_qtde_dezena = {_nr_qtde_dezena}
                                                        )
                                       ORDER BY s.nr_concurso DESC
                                              , s.nr_sorteado ASC"""
                                   )
        if (data == None):
            return None
        
        return SorteioFactory.ConverterDto(_id_tipo_jogo, data)     

    def busca_sorteio_agrupado(id_tipo_jogo: int) -> dict:
        data = conector.read_data(f"""SELECT nr_concurso
                                          , dezenas 
                                       FROM vw_sorteio
                                      WHERE id_tipo_jogo={id_tipo_jogo} 
                                      ORDER BY nr_concurso DESC"""
                                )
        return data

    def busca_sorteio_por_concurso(id_tipo_jogo: int, nr_concurso_inicial: int, nr_concurso_final: int) -> dict:
        data = conector.read_data_new(f"""SELECT nr_concurso
                                          , dezenas as nr_dezenas
                                       FROM vw_sorteio
                                      WHERE id_tipo_jogo={id_tipo_jogo} 
                                        AND nr_concurso BETWEEN {nr_concurso_inicial} AND {nr_concurso_final}
                                      ORDER BY nr_concurso DESC"""
                                )

        return data

    def busca_resultado_por_concurso(id_tipo_jogo:int, nr_concurso:int) -> list[SorteadoDto]:
        data = conector.read_data_new(f"""select nr_sorteado
                                            from sorteio s 
                                           where nr_concurso = {nr_concurso}
                                             and id_tipo_jogo = {id_tipo_jogo}"""
                                    )
        if (data == None):
            return None
        return [SorteadoDto(**d) for d in data]

    def busca_resultado_moldura(id_tipo_jogo:int) -> dict:
        data = conector.read_data_new(f"""select m.nr_concurso
                                               , m.ds_dezenas
                                               , m.id_tipo_jogo
                                            from vw_resultado_moldura m
                                           where m.id_tipo_jogo = {id_tipo_jogo}"""
                                    )
        if (data == None):
            return None

        return data

    def busca_resultado_centro(id_tipo_jogo:int) -> dict:
        data = conector.read_data_new(f"""select c.nr_concurso
                                               , c.ds_dezenas
                                               , c.id_tipo_jogo
                                            from vw_resultado_centro c
                                           where c.id_tipo_jogo = {id_tipo_jogo}"""
                                    )
        if (data == None):
            return None

        return data
