from atexit import register

from engine_bet.infrastructure.database.conector import conector
from engine_bet.module.bet.dtos.tipo_jogo_premiacao_dto import TipoJogoPremiacaoDto
from engine_bet.module.bet.dtos.type_bet_dto import TypeBetDto
from engine_bet.module.bet.dtos.type_bet_structure import TypeBetStructureDTO


class type_bet_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def read_type_bet(id_type_bet: int) -> TypeBetDto:
        types_bet = conector.read_data(f"""SELECT t.*
                                                , COALESCE(c.nr_concurso_max,0) + 1 AS nr_concurso_max
                                             FROM public.tipo_jogo t
                                                  LEFT JOIN ( SELECT MAX(nr_concurso) AS nr_concurso_max
				                                                   , id_tipo_jogo
				                                                FROM concurso
				                                               GROUP BY id_tipo_jogo
				                                            ) c ON c.id_tipo_jogo = t.id_tipo_jogo
                                            WHERE t.id_tipo_jogo={id_type_bet}"""
                                      )
        if (types_bet == None):
            return None
        
        return TypeBetDto.factory(types_bet)
    
    def read_type_bet_structure(id_type_bet:int) -> TypeBetStructureDTO:
        response = conector.read_data(f"""SELECT id_tipo_jogo
                                               , nr_estrutura_jogo
                                            FROM tipo_jogo_estrutura 
                                           WHERE id_tipo_jogo={id_type_bet}
                                           ORDER BY nr_estrutura_jogo"""
                                     )
        if (response == None):
            return None

        return [TypeBetStructureDTO(id_tipo_jogo=res[0],
                                    nr_estrutura_jogo=res[1]) for res in response]

    def read_type_bet_award(id_type_bet:int) -> TipoJogoPremiacaoDto:
        obj: TipoJogoPremiacaoDto
        response = conector.read_data(f"""SELECT id_tipo_jogo 
                                               , min(qt_dezena_acerto) as qt_dezena_acerto
                                            FROM tipo_jogo_premiacao tjp 
                                           WHERE id_tipo_jogo = {id_type_bet}
                                             AND ind_valor_variavel = '0'
                                           GROUP BY id_tipo_jogo"""
                                     )
        if (response == None):
            return None

        obj = [TipoJogoPremiacaoDto(id_tipo_jogo=res[0],
                                    qt_dezena_acerto=res[1]) for res in response]
        return obj[0]