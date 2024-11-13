import random
from engine_bet.module.bet.dtos.calculate_dto import CalculateDTO
from engine_bet.module.bet.dtos.raffle_dto import RaffleDto
from engine_bet.module.bet.repositories.bet_repository import bet_repository
import numpy as np

from engine_bet.module.bet.repositories.raffle_repository import raffle_repository
from engine_bet.module.bet.repositories.type_bet_repository import type_bet_repository

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
    lista_total = get_result_bet(id_type_bet, betInput, False)
    return lista_total

def raffle_by_id(id_type_bet: int, cicle: bool) -> dict:
    tipo_jogo = type_bet_repository.read_type_bet(id_type_bet)
    if (cicle):
        raffle = raffle_repository.read_raffle_by_cicle(id_type_bet)
        if (raffle == None):
            raffle = raffle_repository.read_raffle(id_type_bet, tipo_jogo.qt_dezena_minima_aposta)
    else:
        raffle = raffle_repository.read_raffle(id_type_bet, tipo_jogo.qt_dezena_minima_aposta)
    
    return RaffleDto.factory(id_type_bet, raffle)

def generate_new_bet(calculos: list[CalculateDTO],
                     filtrar_ausente: bool,
                     dezenas_filtrar: int,
                     qtde_filtrar_ausente: int,
                     qtde_filtrar_repetido: int) -> dict:
    
    ausente = [c for c in calculos if c.QtAusenciaRecente > 0]
    ausente = [a.NrDezena for a in ausente]
    random.shuffle(ausente)
    
    repeticao = [c for c in calculos if c.QtAusenciaRecente == 0 and c.QtRepeticaoRecente > 0 and c.QtRepeticaoRecente <= dezenas_filtrar]
    repeticao = sorted(repeticao, key=lambda p: p.QtRepeticaoRecente and p.VlProbabilidade, reverse=True)
    repeticao = [a.NrDezena for a in repeticao]
    random.shuffle(repeticao)
    
    if (filtrar_ausente):
        jogo_ausente = random.sample(ausente, k=qtde_filtrar_ausente)
        jogo_repeticao = random.sample(repeticao, k=qtde_filtrar_repetido)
    else:
        # verificar
        jogo_ausente = random.sample(ausente, k=qtde_filtrar_ausente)
        jogo_repeticao = random.sample(repeticao, k=qtde_filtrar_repetido)
    
    jogo = sorted(jogo_ausente + jogo_repeticao)

    return jogo

def get_result_bet(id_type_bet: int,
                   bets: str,
                   validate_winning_bet: bool = False):
    tipo_jogo = type_bet_repository.read_type_bet(id_type_bet)
    sorteios = bet_repository.read_data_bet(id_type_bet)
    premiacoes = bet_repository.read_type_bet_prize_amount(id_type_bet)
    lista_resultado = []
    lista_total = []
    aposta = bets.split(',')
    for s in sorteios:
        sorteioString = str(s[1])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        lista_resultado.append(len(resultado))
    if (validate_winning_bet):
        acerto = [a for a in lista_resultado if a == tipo_jogo.qt_dezena_resultado]
        return (len(acerto) > 0)
    else:        
        for p in premiacoes:
            prm = p[0]
            acertos = [acerto for acerto in lista_resultado if acerto == prm]
            if (len(acertos)) > 0:
                lista_total.append({"Dezenas": prm, "Acertos": len(acertos)})
            else:
                lista_total.append({"Dezenas": prm, "Acertos": 0})
    
        return lista_total
