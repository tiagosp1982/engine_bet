from atexit import register

from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.dtos.tipo_jogo_premiacao_dto import TipoJogoPremiacaoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_estrutura_dto import TipoJogoEstruturaDTO
from motor_aposta.module.aposta.factories.tipo_jogo_factory import TipoJogoFactory


class tipo_jogo_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def busca_tipo_jogo(id_tipo_jogo: int) -> TipoJogoDTO:
        data = conector.read_data(f"""SELECT t.*
                                                , COALESCE(c.nr_concurso_max,0) + 1 AS nr_concurso_max
                                             FROM public.tipo_jogo t
                                                  LEFT JOIN ( SELECT MAX(nr_concurso) AS nr_concurso_max
				                                                   , id_tipo_jogo
				                                                FROM concurso
				                                               GROUP BY id_tipo_jogo
				                                            ) c ON c.id_tipo_jogo = t.id_tipo_jogo
                                            WHERE t.id_tipo_jogo={id_tipo_jogo}"""
                                      )
        if (data == None):
            return None
        
        return TipoJogoFactory.ConverterDto(data)
    
    def busca_tipo_jogo_estrutura(id_tipo_jogo:int) -> TipoJogoEstruturaDTO:
        data = conector.read_data(f"""SELECT id_tipo_jogo
                                               , nr_estrutura_jogo
                                            FROM tipo_jogo_estrutura 
                                           WHERE id_tipo_jogo={id_tipo_jogo}
                                           ORDER BY nr_estrutura_jogo"""
                                     )
        if (data == None):
            return None

        return [TipoJogoEstruturaDTO(id_tipo_jogo=res[0],
                                    nr_estrutura_jogo=res[1]) for res in data]

    def busca_tipo_jogo_premiacao(id_tipo_jogo:int) -> TipoJogoPremiacaoDTO:
        obj: TipoJogoPremiacaoDTO
        data = conector.read_data(f"""SELECT id_tipo_jogo 
                                               , min(qt_dezena_acerto) as qt_dezena_acerto
                                            FROM tipo_jogo_premiacao tjp 
                                           WHERE id_tipo_jogo = {id_tipo_jogo}
                                           GROUP BY id_tipo_jogo"""
                                     )
        if (data == None):
            return None

        obj = [TipoJogoPremiacaoDTO(id_tipo_jogo=d[0],
                                    qt_dezena_acerto=d[1]) for d in data]
        return obj[0]

    def busca_dezenas_premiacao(id_tipo_jogo: int) -> dict:
        data = conector.read_data(f"""SELECT qt_dezena_acerto 
                                                         FROM tipo_jogo_premiacao 
                                                        WHERE id_tipo_jogo={id_tipo_jogo}
                                                        ORDER BY 1"""
                                                    )
        return data