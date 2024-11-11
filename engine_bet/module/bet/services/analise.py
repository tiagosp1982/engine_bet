import pandas as pd
from engine_bet.module.bet.dtos.calculate_dto import CalculateDTO
from engine_bet.module.bet.dtos.probability_dto import ProbabilityDTO
from engine_bet.module.bet.dtos.raffle_dto import RaffleDto
from engine_bet.module.bet.dtos.type_bet_dto import TypeBetDto
from engine_bet.module.bet.dtos.type_bet_structure import TypeBetStructureDTO
from engine_bet.module.bet.repositories.type_bet_repository import type_bet_repository
from engine_bet.module.bet.services.service import raffle_by_id

tipo_jogo_estrutura: TypeBetStructureDTO
tipo_jogo: TypeBetDto

id = 2
tipo_jogo_estrutura = type_bet_repository.read_type_bet_structure(id)
tipo_jogo = type_bet_repository.read_type_bet(id)

dados = raffle_by_id(id, False)
sorteios = RaffleDto.factoryRaffleOnly(dados)

numeros_por_sorteio = tipo_jogo.qt_dezena_resultado

n_sorteios = len(sorteios) / numeros_por_sorteio
numeros_possiveis = list(range(1, len(tipo_jogo_estrutura) + 1))  

df = pd.DataFrame(sorteios, columns=[f"Num_{i+1}" for i in range(numeros_por_sorteio)])

# Unindo todas as colunas de sorteios em uma única série para contar a frequência de cada número
todos_numeros = pd.Series(df.values.ravel())
frequencia = todos_numeros.value_counts().sort_index().convert_dtypes(convert_integer=True)

# Análise de Probabilidade Empírica
total_sorteios = n_sorteios * numeros_por_sorteio
probabilidades_empiricas = (frequencia / total_sorteios).convert_dtypes(convert_integer=True)
print("\nProbabilidade Empírica dos Números serem Sorteados (em %):")

probabilidades = []
list_probabilidade = (probabilidades_empiricas * 100).round(2).to_frame().T.to_dict()
for key in list_probabilidade:
    probabilidades.append(ProbabilityDTO(number=key, probability=list_probabilidade[key]['count']))

calculos: list
concurso_anterior = 0
qtde_ausencia_recente = 0
qtde_ausencia_total = 0
finaliza_ausencia_recente: bool

for item in tipo_jogo_estrutura:
    finaliza_ausencia_recente = False
    qtde_ausencia_recente = 0
    qtde_ausencia_total = 0
    calculo = CalculateDTO(NrDezena=item.nr_estrutura_jogo)
    
    
    for resultado in sorteios:
        # valida ausência
        if (not item.nr_estrutura_jogo in resultado):
            qtde_ausencia_total += 1
            if (not finaliza_ausencia_recente):
                qtde_ausencia_recente += 1
        else:
            if (not finaliza_ausencia_recente):
                calculo = CalculateDTO(QtAusenciaRecente=qtde_ausencia_recente)

            finaliza_ausencia_recente = True
            qtde_ausencia_recente = 0
    
    calculo = CalculateDTO(QtAusenciaTotal=qtde_ausencia_total)

        
            
