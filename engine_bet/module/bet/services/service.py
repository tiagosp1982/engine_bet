from itertools import combinations
import random
from engine_bet.module.bet.dtos.calculate_dto import CalculateDTO
from engine_bet.module.bet.dtos.raffle_dto import RaffleDto
from engine_bet.module.bet.dtos.simulacao_dto import SimulacaoDto
from engine_bet.module.bet.factories.simulacao_factory import SimulacaoFactory
from engine_bet.module.bet.repositories.bet_repository import bet_repository
import numpy as np

from engine_bet.module.bet.repositories.raffle_repository import raffle_repository
from engine_bet.module.bet.repositories.simulation_repository import simulation_repository
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

def raffle_by_id(id_type_bet: int, cicle: bool, historical: bool = False) -> dict:
    tipo_jogo_estrutura = type_bet_repository.read_type_bet_structure(id_type_bet)
    limit_data = len(tipo_jogo_estrutura)
    if (historical):
        tipo_jogo = type_bet_repository.read_type_bet(id_type_bet)
        limit_data = tipo_jogo.nr_concurso_max

    if (cicle):
        raffle = raffle_repository.read_raffle_by_cicle(id_type_bet)
        if (raffle == None):
            raffle = raffle_repository.read_raffle(id_type_bet, limit_data)
    else:
        raffle = raffle_repository.read_raffle(id_type_bet, limit_data)
    
    return RaffleDto.factory(id_type_bet, raffle)

def generate_new_bet(calculos: list[CalculateDTO],
                     dezenas_filtrar: int,
                     qtde_filtrar_ausente: int,
                     qtde_filtrar_repetido: int,
                     somente_ausente: bool) -> dict:
    
    ausente = [c for c in calculos if c.QtAusenciaRecente > 0]
    ausente = sorted(ausente, key=lambda p: p.VlProbabilidade)
    ausente = [a.NrDezena for a in ausente]
    
    repeticao = [c for c in calculos if c.QtAusenciaRecente == 0 and c.QtRepeticaoRecente > 0 and c.QtRepeticaoRecente <= dezenas_filtrar]
    repeticao = sorted(repeticao, key=lambda p: p.VlProbabilidade)
    repeticao = [a.NrDezena for a in repeticao]

    jogo_ausente = random.sample(ausente, k=(qtde_filtrar_ausente if not somente_ausente else qtde_filtrar_ausente + qtde_filtrar_repetido))
    jogo_repeticao = random.sample(repeticao, k=(qtde_filtrar_repetido if not somente_ausente else 0))
    
    jogo = sorted(jogo_ausente + jogo_repeticao)

    return jogo

def get_result_bet(id_type_bet: int,
                   bets: str,
                   valida_jogos: bool = False,
                   bet_simulation_result: list = None,
                   qtde_maxima_repetida_simulacao_resultado: int = None,
                   desvio_medio: float = None,
                   sempre_amarrar_jogos: bool = False,
                   id_usuario: int = 0
                   ):

    tipo_jogo = type_bet_repository.read_type_bet(id_type_bet)
    sorteios = bet_repository.read_data_bet(id_type_bet)
    premiacoes = bet_repository.read_type_bet_prize_amount(id_type_bet)
    lista_resultado = []
    lista_resultado_adicional = []
    lista_simulado = []
    lista_total = []
    aposta = bets.split(',')
    for s in sorteios:
        sorteioString = str(s[1])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        lista_resultado.append(len(resultado))

    # Verifica se é apenas para validar os jogos ou retornar as informações de acerto (Refatorar)
    if (valida_jogos):
        resultado: bool = False
        # Valida se o jogo já foi sorteado com a qtde máxima por tipo de jogo
        acerto = [a for a in lista_resultado if a == tipo_jogo.qt_dezena_resultado]
        resultado = (len(acerto) > 0)

        # Verifica se já foi sorteado
        if (resultado):
            return True
        
        # Verifica desvio padrão da aposta gerada
        perc_desvio = (desvio_medio * 0.2)
        desvio_gerado = []
        desvio_gerado.append([int(n) for n in aposta])
        for i, row in enumerate(desvio_gerado):
            dev = np.std(row)

        # Verifica se o jogo gerado está dentro da média de desvio padrão + 20% ou na média de desvio padrão - 20%
        if ((dev > (desvio_medio + perc_desvio).__round__(2)) or (dev < (desvio_medio - perc_desvio).__round__(2))):
            return True

        # Valida os jogos já gerados para esse concurso
        dados = simulation_repository.read_simulation_item(id_tipo_jogo=id_type_bet, 
                                                           id_usuario=id_usuario,
                                                           nr_concurso_aposta=tipo_jogo.nr_concurso_max)
        simulados = SimulacaoFactory.simulationOnly(dados)    
        if (simulados):
            for simulado in simulados:
                resultado = [n for n in aposta if n in simulado]
                lista_simulado.append(len(resultado))

            if (sempre_amarrar_jogos):
                acerto_jogo_adicional = [s for s in lista_simulado if s >= qtde_maxima_repetida_simulacao_resultado]
                resultado = (len(acerto_jogo_adicional) == 0)
            else:
                acerto_jogo_adicional = [s for s in lista_simulado if s > qtde_maxima_repetida_simulacao_resultado]
                resultado = (len(acerto_jogo_adicional) > 0)

            if (resultado):
                return True

        # Verifica se existe um jogo extra para usar como comparação ao jogo gerado
        if (bet_simulation_result):
            combinacoes = list(combinations(bet_simulation_result, tipo_jogo.qt_dezena_resultado))
            for combinacao in combinacoes:
                resultado = [elemento for elemento in aposta if elemento in combinacao]
                lista_resultado_adicional.append(len(resultado))

            # Valida as combinações dos jogos extras
            if (lista_resultado_adicional):
                if (sempre_amarrar_jogos):
                    acerto_jogo_adicional = [a for a in lista_resultado_adicional if a >= qtde_maxima_repetida_simulacao_resultado]
                    resultado = (len(acerto_jogo_adicional) == 0)
                else:
                    acerto_jogo_adicional = [a for a in lista_resultado_adicional if a > qtde_maxima_repetida_simulacao_resultado]
                    resultado = (len(acerto_jogo_adicional) > 0)

            return resultado        
    else:        
        for p in premiacoes:
            prm = p[0]
            acertos = [acerto for acerto in lista_resultado if acerto == prm]
            if (len(acertos)) > 0:
                lista_total.append({"Dezenas": prm, "Acertos": len(acertos)})
            else:
                lista_total.append({"Dezenas": prm, "Acertos": 0})
    
        return lista_total

def update_simulacao(id_simulacao: int,
                    id_tipo_jogo: int,
                    id_usuario: int,
                    nr_concurso: int,
                    numeros_simulados: dict) -> bool:

    obj = SimulacaoDto(id_simulacao=id_simulacao,
                       id_tipo_jogo=id_tipo_jogo,
                       id_usuario=id_usuario,
                       nr_concurso=nr_concurso)
    response = simulation_repository.save_simulation(obj)
    if (response):
        itens = SimulacaoFactory.item(obj, numeros_simulados)
        simulation_repository.save_item_simulation(itens)


