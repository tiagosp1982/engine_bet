from engine_bet.module.bet.repositories.bet_repository import bet_repository
import numpy as np

def __init__(cls):
        pass

async def confer_bet_detail(betInput) -> dict:
    sorteios = bet_repository.read_data_bet()
    lista_resultado = []

    aposta = betInput.split(',')
    for s in sorteios:
        sorteioString = str(s[1])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        lista_resultado.append({"Concurso": s[0], "Acertos": len(resultado)})
    
    return lista_resultado

async def confer_bet_total(betInput) -> dict:
    sorteios = bet_repository.read_data_bet()
    premiacoes = bet_repository.read_type_bet_prize_amount()
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
       

def frequency() -> dict: 
    freq = {}
    my_list = bet_repository.read_raffle()
    
    for item in np.unique(np.array(my_list)):
         freq[item] = np.where(np.array(my_list)==item)[0].shape[0]

    return freq