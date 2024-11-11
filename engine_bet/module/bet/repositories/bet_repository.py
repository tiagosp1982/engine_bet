from engine_bet.infrastructure.database.conector import conector
from atexit import register


class bet_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def read_data_bet(id_type_bet: int) -> dict:
        bet = conector.read_data(f"SELECT nr_concurso, dezenas FROM vw_sorteio WHERE id_tipo_jogo={id_type_bet} ORDER BY nr_concurso DESC")
        return bet
    
    def read_type_bet_prize_amount(id_type_bet: int) -> dict:
        type_bet_prize_amount = conector.read_data(f"SELECT qt_dezena_acerto FROM tipo_jogo_premiacao WHERE id_tipo_jogo={id_type_bet}")
        return type_bet_prize_amount
