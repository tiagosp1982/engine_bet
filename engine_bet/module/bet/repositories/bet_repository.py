from engine_bet.infrastructure.database.conector import conector
from atexit import register
from engine_bet.module.bet.dtos.type_bet_dto import TypeBetDto

class bet_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def read_data_bet() -> dict:
        bet = conector.read_data("SELECT * FROM vw_sorteio ORDER BY nr_concurso DESC")
        return bet
    
    def read_type_bet_prize_amount() -> dict:
        type_bet_prize_amount = conector.read_data("SELECT qt_dezena_acerto FROM tipo_jogo_premiacao")
        return type_bet_prize_amount
    
    def read_raffle() -> dict:
        raffle = conector.read_data("SELECT nr_sorteado FROM sorteio ORDER BY 1")
        return raffle
    
    def read_type_bet(id_type_bet: int) -> dict:
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