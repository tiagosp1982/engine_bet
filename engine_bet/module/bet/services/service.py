from engine_bet.module.bet.dtos.raffle_dto import RaffleDto
from engine_bet.module.bet.repositories.bet_repository import bet_repository
import numpy as np

from engine_bet.module.bet.repositories.raffle_repository import raffle_repository

def __init__(cls):
        pass

async def confer_bet_detail(id_type_bet: int, betInput: str) -> dict:
    sorteios = bet_repository.read_data_bet(id_type_bet)
    lista_resultado = []

    aposta = betInput.split(',')
    for s in sorteios:
        sorteioString = str(s[1])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        lista_resultado.append({"Concurso": s[0], "Acertos": len(resultado)})
    
    return lista_resultado

async def confer_bet_total(id_type_bet: int, betInput: str) -> dict:
    sorteios = bet_repository.read_data_bet(id_type_bet)
    premiacoes = bet_repository.read_type_bet_prize_amount(id_type_bet)
    lista_resultado = []
    lista_total = []

    aposta = betInput.split(',')
    for s in sorteios:
        sorteioString = str(s[1])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        lista_resultado.append(len(resultado))

    for p in premiacoes:
        prm = p[0]
        acertos = [acerto for acerto in lista_resultado if acerto == prm]
        if (len(acertos)) > 0:
            lista_total.append({"Dezenas": prm, "Acertos": len(acertos)})
        else:
            lista_total.append({"Dezenas": prm, "Acertos": 0})
    
    return lista_total

def raffle_by_id(id_type_bet: int, cicle: bool) -> dict:
    if (cicle):
        raffle = raffle_repository.read_raffle_by_cicle(id_type_bet)
        if (raffle == None):
            raffle = raffle_repository.read_raffle(id_type_bet)
    else:
        raffle = raffle_repository.read_raffle(id_type_bet)
    
    return RaffleDto.factory(id_type_bet, raffle)
