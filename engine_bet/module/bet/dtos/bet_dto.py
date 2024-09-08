from pydantic import BaseModel

class BetDto(BaseModel):
    def __init__(self, list_bet: list):
        self.bet = [item for item in list_bet]
    
    my_bets: list[int]